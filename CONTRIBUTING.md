# Contributing

This repository is a specification. A change here changes what other people's
clients and servers implement, so please keep it to the point.

## Proposing a change

1. Open an issue describing the packet or behaviour, which end changes, and
   why. A wire change breaks existing implementations; say which ones you
   have updated.
2. Send a pull request with the change to the Typst source (below). Keep the
   table style: one table per packet, `Field Name | Field Type | Notes`, sizes
   in the same row as the packet id.
3. If the change affects code, update `examples/c/` (and the Godot copy) and
   run `make test` in `examples/c/`. The golden vectors in the tests are the
   same bytes the documents show.

## Editing the documents

The pages are Typst files in `src/pages/` (one per page); `src/template.typ`
holds the layout, `src/style.css` the website's stylesheet, and the files
directly in `src/` only tie a page to the template.

* Headings carry a label, `= Chat Message <protocol10:chat-message>`: the part
  after the colon is the anchor on the website (`protocol10#chat-message`).
  Do not rename a heading without keeping its old label, or links to it break.
* A packet is a heading, `#dir("Server -> Client")`, an info table and a field
  table. `#note[...]` and `#warning[...]` are the boxes for notes.
* Link to another page with `#xref("protocol075", anchor: "data-types")[text]`
  (leave `anchor` out for the page itself). It is a relative link on the
  website, an internal link in the book and a link to the site in a single PDF.
* Typst's smart quotes are off on purpose: this is a specification and `1's`
  must stay `1's`.

```sh
make site          # HTML into site/, PDFs into site/pdf/
make check         # needs a built site; builds it first
make preview-publish   # push site/ to the gh-pages-preview branch
```

`make check` compares the built HTML with the Markdown the pages were converted
from (headings, every table cell, every code block, every link, all the words),
then checks every link and anchor in the site. Run it before every pull
request. For a deliberate change to the wording the comparison fails by design;
change `REF` in `tools/fidelity.py` to the commit that holds the new reference
or drop the check for that page in the same pull request, and say so.

Typst's HTML export is experimental. Use Typst 0.15; a newer one may need
changes in `src/template.typ`.

## Style

* English, present tense, short sentences.
* Every packet says its direction (`Client -> Server`, `Server -> Client` or
  both), its packet id and its total size.
* Do not remove a field or rename one silently: say what replaced it.
* `Uint8`, `Uint16`, `Uint32`, `Int8`, `Float`, `Vec3`, `Color` (B, G, R
  unless stated), `String` (UTF-8 unless stated), `Varint` and `Svarint`, as
  defined in [Protocol 1.0](https://ngspades.github.io/protocol/protocol10#data-types) and
  [Protocol 0.75](https://ngspades.github.io/protocol/protocol075#data-types).

## Licence

By contributing you agree that the text is licensed under CC BY 4.0 and the
example code under the MIT licence. See [LICENSE](LICENSE).
