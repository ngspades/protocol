#!/usr/bin/env python3
"""Link check over the built site (internal links only, no network).

  * every internal href and src resolves to a file (or a directory with an index.html),
  * every #fragment exists as an id in the page it points at,
  * every page is reachable both as /page.html and as /page/index.html,
  * 404.html, style.css, .nojekyll and the PDFs exist.

Root-relative links (404.html's) are resolved against the /protocol/ prefix the
site is served under. External links are not requested.
"""
import html.parser
import sys
import urllib.parse
from pathlib import Path

PREFIX = "/protocol/"
PAGES = ["index", "protocol075", "protocol10", "extensions", "protocolmaster", "protocolping"]


class Page(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links = set(), []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        if tag == "a" and "name" in a:
            self.ids.add(a["name"])
        for key in ("href", "src"):
            if key in a and tag != "meta":
                self.links.append((tag, a[key]))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    site = Path(args[0] if args else "site").resolve()
    bad = []

    for need in ("404.html", "style.css", ".nojekyll", "index.html", "pdf/ngspades-protocol.pdf"):
        if not (site / need).exists():
            bad.append("missing %s" % need)
    for p in PAGES:
        pdf = site / "pdf" / (p + ".pdf")
        if not pdf.exists():
            bad.append("missing %s" % pdf.relative_to(site))
        if p != "index":
            for f in (site / (p + ".html"), site / p / "index.html"):
                if not f.exists():
                    bad.append("missing %s" % f.relative_to(site))

    parsed = {}
    htmls = sorted(site.rglob("*.html"))
    for f in htmls:
        p = Page()
        p.feed(f.read_text())
        parsed[f] = p

    count = 0
    for f, p in parsed.items():
        rel = f.relative_to(site)
        for tag, link in p.links:
            count += 1
            u = urllib.parse.urlsplit(link)
            if u.scheme in ("http", "https"):
                continue
            if u.scheme in ("mailto", "data", "javascript"):
                continue
            path = u.path
            if path.startswith(PREFIX):
                target = site / path[len(PREFIX):]
            elif path.startswith("/"):
                bad.append("%s: root-relative link %s is outside %s" % (rel, link, PREFIX))
                continue
            elif path == "":
                target = f
            else:
                target = (f.parent / path)
            target = Path(str(target).rstrip("/")) if path.endswith("/") or path == PREFIX else target
            if target.is_dir():
                target = target / "index.html"
            if not target.resolve().is_relative_to(site) or not target.exists():
                bad.append("%s: %s -> %s does not exist" % (rel, link, target.relative_to(site) if target.is_relative_to(site) else target))
                continue
            if u.fragment and target.suffix == ".html":
                tp = parsed.get(target)
                if tp is None or u.fragment not in tp.ids:
                    bad.append("%s: %s -> no #%s in %s" % (rel, link, u.fragment, target.relative_to(site)))

    # both URL forms of a page must carry the same ids (same document)
    for p in PAGES[1:]:
        a, b = parsed.get(site / (p + ".html")), parsed.get(site / p / "index.html")
        if a and b and a.ids != b.ids:
            bad.append("%s.html and %s/index.html have different ids" % (p, p))

    print("linkcheck: %d pages, %d links" % (len(htmls), count))
    for b in bad:
        print("  " + b)
    if bad:
        print("linkcheck: %d problem(s)" % len(bad))
        sys.exit(1)
    print("linkcheck: ok")


if __name__ == "__main__":
    main()
