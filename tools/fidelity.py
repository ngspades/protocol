#!/usr/bin/env python3
"""Fidelity check: is the built HTML the same document as the Markdown it replaced?

The reference is the Markdown pages of the last Jekyll commit, read with
`git show <ref>:<file>` (REF below, a commit that stays in this repository's
history). For every page it compares

  * the headings (level and text),
  * every table, cell by cell,
  * every fenced code block, line by line,
  * every inline code span, in order,
  * every link target, in order,
  * all the text, as a sequence of words and as a multiset of characters,
  * that each heading's old Jekyll anchor exists as an id.

Anything missing, added or changed is printed and the exit status is 1.
Run it with `make check`.
"""
import argparse
import difflib
import html.parser
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REF = "662054d03e9f682798051bfbb0d920233ff90c17"
# Wording changed on purpose after the Jekyll commit (the software is named
# ngspades-client and ngspades-server now): applied to the reference text, so
# the check still catches every other difference.
RENAMES = [("[Shoot and Destroy](https://ngspades.obex.pw/) client and server",
            "[ngspades-client and ngspades-server](https://ngspades.obex.pw/)"),
           ("**Shoot and Destroy 1.0** (ngspades)", "**ngspades 1.0**"),
           ("the Shoot and Destroy client", "ngspades-client"), ("the Shoot and Destroy server", "ngspades-server"),
           ("the Shoot and Destroy\nserver", "ngspades-server"),
           ("Shoot and Destroy Protocol Documentation", "ngspades Protocol Documentation"),
           ("Shoot and Destroy Protocol", "ngspades Protocol"), ("Shoot and Destroy", "ngspades")]
# Content corrections after the Jekyll commit (the code settled a divergence):
# applied to the reference text after RENAMES, one entry each with its reason,
# so the check still catches every other difference.
CORRECTIONS = [
    # handshake deadlines: Session.c's P10_TIMEOUT_* constants are 5 s and 10 s
    ("10 s for\n`Initiate Connection`, 10 s for the certificate, 300 s for the map transfer.\n",
     "5 s for\n`Initiate Connection` (`P10_TIMEOUT_INITIATE`), 10 s for the certificate\n"
     "(`P10_TIMEOUT_CERT`), 300 s for the map transfer (`P10_TIMEOUT_MAP`), and 3 s\n"
     "for the client's answer to `map-cached` (`P10_TIMEOUT_MAP_ANSWER`). The reference\n"
     "server waited 10 s and 60 s; ours is stricter because an unfinished handshake\n"
     "holds a player slot. A client answers both steps in milliseconds, so it should\n"
     "not rely on more than the shorter figures.\n"),
    # map-size: the server writes size_x,size_y,size_z and 1024 maps exist
    ("| `map-size` | `512,512,64` | width, height, depth |",
     "| `map-size` | `512,512,64` or `1024,1024,64` | `x,y,z` in the server's order: `x` and `y` are the two horizontal axes, `z` the 64 deep height. Ours sends 512 x 512 or 1024 x 1024 maps and the client accepts only those two square sizes, depth 64, refusing anything else before decoding |"),
    # neutral team numbers (what servers send vs what a client should accept)
    ("`0`, `1` or `2` (neutral).",
     "`0` or `1`, or neutral. Servers send neutral as `2` (pyspades and piqueserver\n"
     "do; our server's 0.75 profile has no TC, so it never sends one). A client\n"
     "should read any value other than `0` or `1` as neutral in territory and\n"
     "object packets, and as spectator (`-1`) in every packet that names a player's\n"
     "team. Some drafts treat `2` as a \"neutral spectator\" and `3` as neutral; the\n"
     "rule above covers both."),
    ("| Team | Uint8 | 0, 1 or 2 (neutral) |", "| Team | Uint8 | 0 or 1; any other value is neutral (servers send 2) |"),
    # chat colour bytes: say what travels in which encoding
    ("`0x08` yellow. `\\n` and `\\r` break the line.\n",
     "`0x08` yellow. `\\n` and `\\r` break the line.\n\n"
     "On the wire, `0x01`-`0x07` are the colour bytes real servers send, in both\n"
     "encodings; `0x08` (yellow) belongs to the UTF-8 variant of the text (the one\n"
     "that begins with `0xFF`), so a CP437 string from a server that does not speak\n"
     "UTF-8 does not carry it. A reader should treat every other byte below `0x20`\n"
     "as having no colour meaning. This describes what travels, not what any\n"
     "particular client draws.\n"),
    # Ext Info count wording
    ("`+1`. A client reading", "`+1`. (The wording is\nthe aosprotocol specification's; its own implementations count entries, as\nours do.) A client reading"),
]
# The ASCII sequence diagrams of the Markdown are SVG figures now (the Typst
# `sequence` helper): the fenced block, found by its first line, is replaced in
# the reference by the figure's caption, the only text the figure has.
DIAGRAMS = [("client                                            server", "The connection, from the first packet to the game."),
            ("browser                              master                       game server",
             "WebRTC signalling through the master.")]
# Pages changed on purpose after the Markdown, with the reason: the comparison
# is not made for them (CONTRIBUTING: drop the check for a page in the pull
# request that changes its wording, and say so).
SKIP = {"protocol075": "audited against the clidoc, LSd and SpadesX: Short Player Data, State Data size, Existing Player size, Light sub ids, orientation rule, Set HP, Block Line, quirks, weapons and sources",
        "index": "ZeroSpades and KyroSpades added to the implementers and the resources",
        "extensions": "ZeroSpades' and KyroSpades' extensions added, Edit Mode and the proposals registered, "
                      "Pie Menu, Damage Markers and Teamplay laid out, Flashlight cone and Daytime fields corrected"}
PAGES = {"index": "index.md", "protocol075": "protocol075.md", "protocol10": "protocol10.md",
         "extensions": "extensions.md", "protocolmaster": "protocolmaster.md", "protocolping": "protocolping.md"}
GH = "https://github.com/ngspades/protocol/blob/main/"
PAGE_OF_MD = {v: k for k, v in PAGES.items()}


def norm(s):
    """Typst turns straight quotes into curly ones; nothing else may change."""
    return (s.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
             .replace(" ", " "))


def ws(s):
    return " ".join(norm(s).split())


# ---------------------------------------------------------------- Markdown --

LINK = r"\[((?:[^\[\]`]|`[^`]*`)*)\]\(([^)]*)\)"


def md_plain(s):
    """Inline Markdown to the text a reader sees."""
    s = re.sub(LINK, r"\1", s)
    out = []
    # code spans are literal; only the text between them has emphasis markers
    for i, part in enumerate(re.split(r"(`[^`]*`)", s)):
        if i % 2:
            out.append(part[1:-1])
        else:
            part = part.replace("**", "")
            part = re.sub(r"(?<![\w*])\*(?=\S)|(?<=\S)\*(?![\w*])", "", part)
            out.append(part)
    return "".join(out).replace("\\|", "|")


def kramdown_slug(text):
    return re.sub(r"[^a-z0-9 \-_]", "", md_plain(text).lower()).replace(" ", "-")


def split_row(line):
    body = line.strip()[1:-1]
    cells, cur, incode, i = [], "", False, 0
    while i < len(body):
        ch = body[i]
        if ch == "\\" and body[i + 1:i + 2] == "|":
            cur += "\\|"
            i += 2
            continue
        if ch == "`":
            incode = not incode
        if ch == "|" and not incode:
            cells.append(cur)
            cur = ""
            i += 1
            continue
        cur += ch
        i += 1
    cells.append(cur)
    return cells


def expected_href(url, page):
    m = re.match(r"^(\w+\.md)(?:#(.*))?$", url)
    if m:
        return ("page", PAGE_OF_MD[m.group(1)], m.group(2))
    if url.startswith("#"):
        return ("page", page, url[1:])
    if url.startswith("examples/"):
        return ("abs", GH + url)
    return ("abs", url)


def collect(s, spans, links, page):
    """Inline code spans and link targets of one line, in order of appearance."""
    for m in re.finditer(r"`([^`]*)`", s):
        spans.append((m.start(), ws(m.group(1).replace("\\|", "|"))))
    for m in re.finditer(LINK, s):
        links.append((m.start(), expected_href(m.group(2), page)))


def parse_md(src, page):
    headings, tables, codes, spans, links, prose = [], [], [], [], [], []
    slugs = {}
    lines = src.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^(#{1,6}) (.*)$", line)
        if m:
            slug = kramdown_slug(m.group(2))
            n = slugs.get(slug, 0)
            slugs[slug] = n + 1
            headings.append((len(m.group(1)), ws(md_plain(m.group(2))), slug if n == 0 else "%s-%d" % (slug, n)))
            prose.append(md_plain(m.group(2)))
            collect(m.group(2), spans, links, page)
            i += 1
            continue
        if line.startswith("```"):
            j = i + 1
            body = []
            while lines[j] != "```":
                body.append(lines[j].rstrip())
                j += 1
            codes.append(body)
            prose.append("\n".join(body))
            i = j + 1
            continue
        if line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(lines[i])
                i += 1
            parsed = [split_row(r) for r in rows if not re.match(r"^\|[\s\-|:]+\|$", r)]
            tables.append([[ws(md_plain(c)) for c in r] for r in parsed])
            for r in parsed:
                for c in r:
                    prose.append(md_plain(c))
                    collect(c, spans, links, page)
            continue
        if not line.strip():
            i += 1
            continue
        # a paragraph or list item: its lines are one text (links and code spans may wrap)
        block = re.sub(r"^(\*|\d+\.) ", "", line)
        i += 1
        while (i < len(lines) and lines[i].strip() and not re.match(r"^(#{1,6} |```|\||\*\s|\d+\. )", lines[i])):
            block += " " + lines[i].strip()
            i += 1
        prose.append(md_plain(block))
        collect(block, spans, links, page)
    # the loop above visits lines in order, but a table's cells are collected row by row
    # exactly as they appear, so the order of spans and links is the document's
    return dict(headings=headings, tables=tables, codes=codes, spans=[t for _, t in spans],
                links=[e for _, e in links], prose="\n".join(prose))


# -------------------------------------------------------------------- HTML --

class Article(html.parser.HTMLParser):
    """Collects what is inside <article class="doc"> (not the sidebar or the footer)."""
    BLOCK = {"p", "div", "li", "td", "th", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "ul", "ol", "table"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.inside = False
        self.text = []
        self.headings, self.tables, self.codes, self.spans, self.hrefs, self.ids = [], [], [], [], [], set()
        self.head = self.row = self.cell = self.table = self.pre = self.code = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "article" and "doc" in a.get("class", "").split():
            self.inside = True
            return
        if not self.inside:
            return
        if "id" in a:
            self.ids.add(a["id"])
        if tag in self.BLOCK:
            self.text.append("\n")
        if tag == "a" and "href" in a and "hl" not in a.get("class", "").split():
            self.hrefs.append(a["href"])
        if re.fullmatch(r"h[2-6]", tag):
            self.head = [int(tag[1]) - 1, ""]
        elif tag == "table":
            self.table = []
        elif tag == "tr" and self.table is not None:
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = ""
        elif tag == "pre":
            self.pre = ""
        elif tag == "code" and self.pre is None:
            self.code = ""

    def handle_endtag(self, tag):
        if tag == "article":
            self.inside = False
            return
        if not self.inside:
            return
        if tag in self.BLOCK:
            self.text.append("\n")
        if re.fullmatch(r"h[2-6]", tag) and self.head:
            self.headings.append((self.head[0], ws(self.head[1])))
            self.head = None
        elif tag in ("td", "th") and self.cell is not None:
            self.row.append(ws(self.cell))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.table.append(self.row)
            self.row = None
        elif tag == "table" and self.table is not None:
            self.tables.append(self.table)
            self.table = None
        elif tag == "pre" and self.pre is not None:
            self.codes.append([l.rstrip() for l in self.pre.rstrip("\n").split("\n")])
            self.pre = None
        elif tag == "code" and self.code is not None:
            self.spans.append(ws(self.code))
            self.code = None

    def handle_data(self, data):
        if not self.inside:
            return
        self.text.append(data)
        if self.head is not None:
            self.head[1] += data
        if self.cell is not None:
            self.cell += data
        if self.pre is not None:
            self.pre += data
        if self.code is not None:
            self.code += data


# ------------------------------------------------------------------ compare --

def show(items, n=6):
    return "\n".join("      " + repr(x) for x in items[:n]) + ("\n      ..." if len(items) > n else "")


def diff_runs(label, a, b, limit=10):
    out = []
    ops = [o for o in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes() if o[0] != "equal"]
    for op, a0, a1, b0, b1 in ops[:limit]:
        out.append("%s %s: expected %r, built %r" % (label, op, a[max(a0 - 2, 0):a1 + 2][:12], b[max(b0 - 2, 0):b1 + 2][:12]))
    if len(ops) > limit:
        out.append("%s: ... and %d more" % (label, len(ops) - limit))
    return out


def check_page(page, md_file, site, ref):
    problems = []
    src = subprocess.run(["git", "show", "%s:%s" % (ref, md_file)], capture_output=True, text=True, check=True).stdout
    for old, new in RENAMES:
        src = src.replace(old, new)
    for old, new in CORRECTIONS:
        src = src.replace(old, new)
    for first, caption in DIAGRAMS:
        i = src.find("```\n" + first)
        if i >= 0:
            j = src.index("```\n", i + 4) + 4
            src = src[:i] + caption + "\n" + src[j:]
    md = parse_md(src, page)
    path = Path(site) / ("index.html" if page == "index" else page + ".html")
    h = Article()
    h.feed(path.read_text())
    if not h.headings:
        return ["no headings in %s" % path]

    want = [(lv, t) for lv, t, _ in md["headings"]]
    if want != h.headings:
        problems += diff_runs("headings", want, h.headings)
    for _, t, slug in md["headings"]:
        if slug not in h.ids:
            problems.append("the old anchor #%s (%s) is not an id in the built page" % (slug, t))

    if len(md["tables"]) != len(h.tables):
        problems.append("tables: %d in Markdown, %d built" % (len(md["tables"]), len(h.tables)))
    for n, (a, b) in enumerate(zip(md["tables"], h.tables), 1):
        if a != b:
            bad = [(x, y) for x, y in zip(a, b) if x != y] or [(a[len(b):], b[len(a):])]
            problems.append("table %d (starts %r) differs: %d rows expected, %d built; first difference:\n      expected %r\n      built    %r"
                            % (n, a[0], len(a), len(b), bad[0][0], bad[0][1]))

    if len(md["codes"]) != len(h.codes):
        problems.append("code blocks: %d in Markdown, %d built" % (len(md["codes"]), len(h.codes)))
    for n, (a, b) in enumerate(zip(md["codes"], h.codes), 1):
        if a != b:
            d = list(difflib.unified_diff(a, b, "markdown", "built", lineterm="", n=0))[:8]
            problems.append("code block %d differs:\n      " % n + "\n      ".join(d))

    if md["spans"] != h.spans:
        problems += diff_runs("inline code", md["spans"], h.spans)

    want_links = []
    for e in md["links"]:
        if e[0] == "abs":
            want_links.append(e[1])
        else:
            _, target, anchor = e
            base = "" if target == page else ("index.html" if target == "index" else target + ".html")
            want_links.append((base + ("#" + anchor if anchor else "")) or "#")
    if want_links != h.hrefs:
        problems += diff_runs("links", want_links, h.hrefs)
    for l in h.hrefs:
        if l.startswith("#") and len(l) > 1 and l[1:] not in h.ids:
            problems.append("link to a missing anchor %s" % l)

    # All the text: as an ordered list of words, then as a multiset of characters.
    # The built article starts with the page title (an h1), which the Markdown never had.
    built = "".join(h.text)
    title = re.match(r"\s*(.*)", built).group(1)
    built = built.replace(title, "", 1)
    mw, hw = ws(md["prose"]).split(), ws(built).split()
    if mw != hw:
        problems += diff_runs("words", mw, hw)
    cm = Counter(c for c in norm(md["prose"]) if not c.isspace())
    ch = Counter(c for c in norm(built) if not c.isspace())
    if cm != ch:
        problems.append("characters differ: missing %s, extra %s" % (dict(cm - ch), dict(ch - cm)))
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default="site")
    ap.add_argument("--ref", default=REF, help="commit holding the Markdown pages (default: the last Jekyll commit)")
    args = ap.parse_args()
    bad = 0
    for page, md_file in PAGES.items():
        if page in SKIP:
            print("%-16s skipped: %s" % (md_file, SKIP[page]))
            continue
        probs = check_page(page, md_file, args.site, args.ref)
        print("%-16s %s" % (md_file, "ok" if not probs else "FAIL"))
        for p in probs:
            print("    " + p)
            bad += 1
    for page in PAGES:
        if page == "index":
            continue
        for f in (Path(args.site, page + ".html"), Path(args.site, page, "index.html")):
            if not f.exists():
                print("missing %s" % f)
                bad += 1
    if bad:
        print("\nfidelity: %d finding(s)" % bad)
        sys.exit(1)
    print("\nfidelity: every page matches its Markdown source")


if __name__ == "__main__":
    main()
