// Shared layout for the ngspades protocol documentation.
//
// One source, two targets. The Makefile compiles every page with
// `--input target=html` (the website) and as a PDF (no input), and the book
// with `--input combined=1`. Everything that differs between the targets is
// in this file; the page sources contain only content.

// ---- inputs ---------------------------------------------------------------

#let inputs = sys.inputs
#let is-html = inputs.at("target", default: "pdf") == "html"
#let cur = inputs.at("page", default: "")
#let combined = inputs.at("combined", default: "0") == "1"
// How many directories below the site root this HTML file is (0 or 1).
#let depth = int(inputs.at("depth", default: "0"))
// An absolute URL prefix, for pages served from any path (404.html).
#let base = inputs.at("base", default: "")
#let up = if base != "" { base } else { "../" * depth }

#let site-url = "https://ngspades.github.io/protocol/"
#let repo-url = "https://github.com/ngspades/protocol"
#let site-title = "ngspades Protocol Documentation"

// ---- pages ----------------------------------------------------------------

#let pages = (
  (id: "index", nav: "Overview", chapter: "Introduction", title: site-title,
   desc: "Ace of Spades 0.75/0.76 and ngspades 1.0: every packet, what the server sends and expects, the master list, WebRTC, and C and Godot examples."),
  (id: "protocol075", nav: "Protocol 0.75 / 0.76", chapter: "Protocol 0.75 and 0.76", title: "Protocol 0.75 and 0.76",
   desc: "The Ace of Spades 0.75 wire protocol and its 0.76 variation: every packet, the game rules and how to write a server."),
  (id: "protocol10", nav: "Protocol 1.0", chapter: "Protocol 1.0", title: "Protocol 1.0",
   desc: "Protocol 1.0, the protocol of ngspades-server: connection over ENet and WebRTC, every packet, entities, trajectories, game mode state and a minimum client."),
  (id: "extensions", nav: "Extensions", chapter: "Extensions", title: "Extensions",
   desc: "The 0.75 protocol extensions: negotiation, the id registry and the extensions our server speaks."),
  (id: "protocolmaster", nav: "Master Server", chapter: "Master Server", title: "Master Server",
   desc: "The classic master and our HTTP master: the list, announcing, WebRTC signalling, join codes and connect tokens."),
  (id: "protocolping", nav: "Ping", chapter: "Ping", title: "Ping",
   desc: "The raw UDP protocol of a server: HELLO, HELLOLAN, HELLOINFO and map previews."),
)

#let page-info(id) = pages.find(p => p.id == id)
#let page-href(id) = if id == "index" { "index.html" } else { id + ".html" }

// ---- colours --------------------------------------------------------------

#let accent = rgb("#b5301f")
#let ink = rgb("#1d1d1f")
#let muted = rgb("#6b6b70")
#let line-colour = rgb("#d9d9de")
#let code-bg = rgb("#f4f4f6")
#let note-bg = rgb("#eaf2fb")
#let note-bar = rgb("#2f6db5")
#let warn-bg = rgb("#fdf1e3")
#let warn-bar = rgb("#c77a12")

#let sans = ("Inter", "Helvetica Neue", "Helvetica", "Arimo", "Liberation Sans", "DejaVu Sans")
#let mono = ("JetBrains Mono", "Menlo", "DejaVu Sans Mono", "Liberation Mono")

// ---- helpers --------------------------------------------------------------

#let el(tag, ..args) = html.elem(tag, attrs: args.named(), args.pos().join())

// A link to another page (and optionally a heading of it). In the website it
// is a relative link, in the book an internal one, in a single PDF a link to
// the published site.
#let xref(page, body, anchor: none) = {
  if is-html {
    let h = if page == cur { "" } else { up + page-href(page) }
    if anchor != none { h += "#" + anchor }
    if h == "" { h = "#" }
    el("a", href: h, body)
  } else if combined or (page == cur and anchor != none) {
    link(label(page + ":" + if anchor == none { "top" } else { anchor }), body)
  } else {
    link(site-url + page-href(page) + if anchor != none { "#" + anchor } else { "" }, body)
  }
}

// The direction line under a packet's name: "Server -> Client".
#let dir(label-text, ..rest) = {
  let tail = rest.pos().join()
  if is-html {
    el("p", class: "dir", { el("code", class: "dir-badge", label-text); [ ]; tail })
  } else {
    block(above: 0.9em, below: 0.6em, breakable: false, {
      box(fill: accent.lighten(88%), stroke: 0.5pt + accent.lighten(55%), radius: 2pt,
        inset: (x: 4pt, y: 2.5pt), text(font: mono, size: 0.85em, fill: accent.darken(15%), label-text))
      [ ]
      tail
    })
  }
}

#let callout(kind, bg, bar, body) = {
  if is-html {
    el("div", class: "callout " + kind, body)
  } else {
    block(width: 100%, fill: bg, stroke: (left: 3pt + bar), inset: (x: 10pt, y: 8pt), radius: (right: 2pt),
      above: 1em, below: 1em, breakable: false, body)
  }
}
#let note(body) = callout("note", note-bg, note-bar, body)
#let warning(body) = callout("warning", warn-bg, warn-bar, body)

// A sequence diagram: lifelines for `actors`, one row per step. A step is
// (from: i, to: j, text: "...") for a message, or (note: "...", at: i) for a
// note on one lifeline, (note: "...", at: (i, j)) across several. The website
// gets an inline SVG (html.frame: drawn by Typst, no script, no font needed),
// the PDF the same drawing. The ASCII art it replaces broke on narrow screens.
#let sequence(actors, steps, caption: none) = {
  let n = actors.len()
  let gap = if n == 2 { 440pt } else { 250pt }
  let first = if n == 2 { 90pt } else { 70pt }
  let x(i) = first + gap * i
  let width = first * 2 + gap * (n - 1)
  let row = 26pt
  let head = 34pt
  let height = head + row * steps.len() + 8pt
  let out-colour = accent
  let in-colour = note-bar
  let drawing = box(width: width, height: height, {
    for (i, a) in actors.enumerate() {
      place(top + left, dx: x(i), dy: 30pt,
        line(start: (0pt, 0pt), end: (0pt, height - 30pt), stroke: (paint: muted.lighten(30%), thickness: 0.8pt, dash: "dashed")))
      place(top + left, dx: x(i) - 52pt, dy: 2pt,
        box(width: 104pt, height: 24pt, fill: ink, radius: 3pt, align(center + horizon,
          text(font: sans, size: 9pt, weight: "bold", fill: white, a))))
    }
    for (k, st) in steps.enumerate() {
      let y = head + row * k + row / 2
      if "note" in st {
        let at = st.at
        let (a, b) = if type(at) == array { (at.first(), at.last()) } else { (at, at) }
        let w = calc.max(x(b) - x(a), 0pt) + 150pt
        place(top + left, dx: (x(a) + x(b)) / 2 - w / 2, dy: y - 10pt,
          box(width: w, height: 20pt, fill: note-bg, stroke: 0.6pt + note-bar.lighten(40%), radius: 3pt,
            align(center + horizon, text(font: sans, size: 8pt, fill: ink, st.note))))
      } else {
        let a = x(st.from)
        let b = x(st.to)
        let right = b > a
        let colour = if right { out-colour } else { in-colour }
        place(top + left, dx: calc.min(a, b), dy: y,
          line(length: calc.abs(b - a), stroke: 1.2pt + colour))
        if right {
          place(top + left, dx: b - 8pt, dy: y - 3.5pt, polygon(fill: colour, (0pt, 0pt), (8pt, 3.5pt), (0pt, 7pt)))
        } else {
          place(top + left, dx: b, dy: y - 3.5pt, polygon(fill: colour, (8pt, 0pt), (0pt, 3.5pt), (8pt, 7pt)))
        }
        place(top + left, dx: calc.min(a, b), dy: y - 12pt,
          box(width: calc.abs(b - a), align(center, text(font: mono, size: 7.6pt, fill: ink, st.text))))
      }
    }
  })
  // What a screen reader gets in place of the picture.
  let said = steps.map(st => if "note" in st { "Note: " + st.note } else {
    actors.at(st.from) + " to " + actors.at(st.to) + ": " + st.text }).join("; ")
  if is-html {
    el("figure", class: "diagram", role: "img", aria-label: said, {
      html.frame(drawing)
      if caption != none { el("figcaption", caption) }
    })
  } else {
    block(width: 100%, breakable: false, above: 1em, below: 1em, align(center, scale(
      x: if width > 15cm { 15cm / width * 100% } else { 100% },
      y: if width > 15cm { 15cm / width * 100% } else { 100% },
      reflow: true, drawing)))
  }
}

// The id a heading gets in HTML: its label without the page prefix, which is
// the same slug Jekyll used, so old links with #anchors keep working.
#let heading-id(h) = {
  let l = h.at("label", default: none)
  if l == none { none } else { str(l).split(":").slice(1).join(":") }
}

// ---- HTML -----------------------------------------------------------------

#let html-sidebar(info) = context {
  let heads = query(heading).filter(h => h.level <= 2 and heading-id(h) != none)
  el("nav", class: "sidebar", {
    el("a", class: "brand", href: up + "index.html", "ngspades")
    el("p", class: "brand-sub", "Protocol documentation")
    el("ul", class: "pages", {
      for p in pages {
        let here = p.id == info.id
        el("li", class: if here { "current" } else { "" }, {
          el("a", href: if here { "#" } else { up + page-href(p.id) }, p.nav)
          if here and heads.len() > 0 {
            el("ul", class: "toc", {
              for h in heads {
                el("li", class: "l" + str(h.level), el("a", href: "#" + heading-id(h), h.body))
              }
            })
          }
        })
      }
    })
    el("p", class: "side-links", {
      el("a", href: up + "pdf/ngspades-protocol.pdf", "Download as PDF")
      el("a", href: repo-url, "Source on GitHub")
      el("a", href: repo-url + "/tree/main/examples", "C and Godot examples")
    })
  })
}

#let html-page(info, body) = {
  let url = site-url + page-href(info.id)
  el("html", lang: "en", {
    el("head", {
      el("meta", charset: "utf-8")
      el("meta", name: "viewport", content: "width=device-width, initial-scale=1")
      el("title", if info.id == "index" { info.title } else { info.title + " | " + site-title })
      el("meta", name: "description", content: info.desc)
      el("link", rel: "canonical", href: url)
      el("link", rel: "stylesheet", href: up + "style.css")
    })
    el("body", el("div", class: "layout", {
      html-sidebar(info)
      el("main", {
        el("article", class: "doc", {
          el("h1", info.title)
          body
        })
        el("footer", {
          [Text: CC BY 4.0. Example code: MIT. Built with Typst from ]
          el("a", href: repo-url, "ngspades/protocol")
          [.]
        })
      })
    }))
  })
}

#let html-doc(info, it) = {
  // Straight quotes stay straight: this is a specification, and Typst would
  // turn the apostrophe in "1's" after a digit into a prime.
  set smartquote(enabled: false)
  show heading: h => {
    let id = heading-id(h)
    let tag = "h" + str(calc.min(h.level + 1, 6))
    el(tag, id: id, el("a", class: "hl", href: "#" + id, h.body))
  }
  show table: t => el("div", class: "table-wrap", t)
  html-page(info, it)
}

// ---- PDF ------------------------------------------------------------------

#let pdf-styles(it) = {
  set smartquote(enabled: false)
  set text(font: sans, size: 10pt, fill: ink, lang: "en")
  set par(justify: false, leading: 0.62em, spacing: 0.95em)
  set page(paper: "a4", margin: (x: 2.2cm, top: 2.4cm, bottom: 2.2cm))
  set heading(numbering: none)
  show heading: set text(fill: ink)
  show heading.where(level: 1): set text(size: 18pt, fill: accent)
  show heading.where(level: 1): set block(above: 1.6em, below: 0.9em)
  show heading.where(level: 2): set text(size: 13.5pt)
  show heading.where(level: 2): set block(above: 1.5em, below: 0.7em)
  show heading.where(level: 3): set text(size: 11pt)
  show heading.where(level: 3): set block(above: 1.3em, below: 0.6em)
  show heading.where(level: 4): set text(size: 10pt)
  show link: set text(fill: note-bar)
  show raw: set text(font: mono, size: 0.88em)
  show raw.where(block: false): it => box(fill: code-bg, inset: (x: 2pt), outset: (y: 2.5pt), radius: 2pt, it)
  show raw.where(block: true): it => block(width: 100%, fill: code-bg, stroke: 0.5pt + line-colour,
    inset: 8pt, radius: 3pt, above: 1em, below: 1em, breakable: false, it)
  set table(stroke: 0.5pt + line-colour, inset: (x: 6pt, y: 4.5pt))
  show table: set text(size: 9pt)
  show table: set block(above: 1em, below: 1em)
  show table.cell.where(y: 0): set text(weight: "semibold")
  set table(fill: (_, y) => if y == 0 { rgb("#eeeef1") } else if calc.odd(y) { rgb("#fafafb") } else { white })
  set list(indent: 0.6em, body-indent: 0.7em, spacing: 0.7em)
  set enum(indent: 0.6em, body-indent: 0.7em, spacing: 0.7em)
  it
}

#let pdf-doc(info, it) = {
  set document(title: info.title + " | " + site-title, author: "ngspades")
  show: pdf-styles
  set page(
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 8.5pt, fill: muted)
        grid(columns: (1fr, auto), info.title, site-url + page-href(info.id))
        v(-0.4em)
        line(length: 100%, stroke: 0.4pt + line-colour)
      }
    },
    footer: context {
      set text(size: 8.5pt, fill: muted)
      align(center, counter(page).display())
    },
  )
  block(below: 1.4em, {
    text(size: 8.5pt, fill: accent, weight: "semibold", tracking: 0.08em, upper(site-title))
    v(0.3em)
    text(size: 24pt, weight: "bold", info.title)
  })
  outline(title: [Contents], depth: 2)
  v(0.6em)
  it
}

// ---- entry points ---------------------------------------------------------

// A single page: the website's HTML, or one PDF.
#let site-page(id, it) = {
  let info = page-info(id)
  if is-html { html-doc(info, it) } else { pdf-doc(info, it) }
}

// The 404 page.
#let not-found-page(it) = {
  html-page((id: "404", nav: "", title: "Not found", desc: "That page does not exist."), it)
}

// All pages as one PDF.
#let book(body) = {
  set document(title: site-title, author: "ngspades")
  show: pdf-styles
  set page(
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 8.5pt, fill: muted)
        grid(columns: (1fr, auto), site-title, site-url)
        v(-0.4em)
        line(length: 100%, stroke: 0.4pt + line-colour)
      }
    },
    footer: context {
      set text(size: 8.5pt, fill: muted)
      align(center, counter(page).display())
    },
  )
  show heading.where(level: 1): it => { pagebreak(weak: true); it }
  v(5cm)
  text(size: 9pt, fill: accent, weight: "semibold", tracking: 0.1em, upper("ngspades"))
  v(0.4em)
  text(size: 30pt, weight: "bold", site-title)
  v(0.8em)
  block(width: 70%, text(size: 12pt, fill: muted)[Ace of Spades 0.75/0.76 and ngspades 1.0: every packet, what the server sends and expects, the master list, WebRTC, and C and Godot examples.])
  v(1fr)
  text(size: 9pt, fill: muted)[#site-url \ #repo-url \ Text: CC BY 4.0. Example code: MIT.]
  pagebreak()
  outline(title: [Contents], depth: 2)
  body
}

// One chapter of the book: its title is a level 1 heading, the page's own
// headings go one level down.
#let chapter(id, content) = {
  let info = page-info(id)
  [#heading(level: 1, info.chapter) #label(id + ":top")]
  set heading(offset: 1)
  content
}
