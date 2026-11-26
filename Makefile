# Build the protocol documentation from the Typst sources in src/.
#
#   make site             the website into site/ (HTML, style.css, 404.html) and
#                         every PDF into site/pdf/
#   make pdf              only the PDFs, into site/pdf/
#   make check            site, then the fidelity check and the link check
#   make clean            remove site/
#   make preview-publish  push site/ to the gh-pages-preview branch
#   make publish          push site/ to the gh-pages branch (the live site's
#                         branch once GitHub Pages is switched to it)
#
# Needs Typst 0.15 or later (HTML export is still experimental there) and
# Python 3. Nothing else.

TYPST   := tools/typst.sh
PAGES   := index protocol075 protocol10 extensions protocolmaster protocolping
SITE    := site
BOOK    := $(SITE)/pdf/ngspades-protocol.pdf
HTMLOPT := --features html --format html --input target=html
SRC     := $(wildcard src/*.typ src/pages/*.typ)

HTML := $(SITE)/index.html $(foreach p,$(filter-out index,$(PAGES)),$(SITE)/$(p).html $(SITE)/$(p)/index.html)
PDFS := $(foreach p,$(PAGES),$(SITE)/pdf/$(p).pdf) $(BOOK)

.PHONY: all site pdf check clean preview-publish publish
all: site

site: $(HTML) $(SITE)/404.html $(SITE)/style.css $(SITE)/.nojekyll $(SITE)/examples $(PDFS)

pdf: $(PDFS)

# /page.html is compiled for relative links from the site root, /page/index.html
# for relative links one directory down (GitHub Pages serves either one for
# /page, and other repositories link both /page and /page.html).
$(SITE)/index.html: src/index.typ $(SRC)
	@mkdir -p $(SITE)
	$(TYPST) $(HTMLOPT) --input page=index --input depth=0 $< $@

$(SITE)/%.html: src/%.typ $(SRC)
	@mkdir -p $(SITE)
	$(TYPST) $(HTMLOPT) --input page=$* --input depth=0 $< $@

$(SITE)/%/index.html: src/%.typ $(SRC)
	@mkdir -p $(SITE)/$*
	$(TYPST) $(HTMLOPT) --input page=$* --input depth=1 $< $@

# Served from any path on a missing page, so its links are absolute.
$(SITE)/404.html: src/404.typ $(SRC)
	@mkdir -p $(SITE)
	$(TYPST) $(HTMLOPT) --input base=/protocol/ $< $@

$(SITE)/style.css: src/style.css
	@mkdir -p $(SITE)
	cp $< $@

# Without it GitHub Pages would run Jekyll over the pushed branch.
$(SITE)/.nojekyll:
	@mkdir -p $(SITE)
	touch $@

# The old Jekyll site served the examples' README pages; they stay Markdown in
# the repository (GitHub shows them), so these paths redirect there.
$(SITE)/examples: tools/redirect.sh
	@mkdir -p $(SITE)
	tools/redirect.sh $(SITE)

$(SITE)/pdf/%.pdf: src/%.typ $(SRC)
	@mkdir -p $(SITE)/pdf
	$(TYPST) --input page=$* $< $@

$(BOOK): src/all.typ $(SRC)
	@mkdir -p $(SITE)/pdf
	$(TYPST) --input combined=1 $< $@

check: site
	python3 tools/fidelity.py --site $(SITE)
	python3 tools/linkcheck.py $(SITE)

clean:
	rm -rf $(SITE)

preview-publish: site
	tools/publish.sh $(SITE) gh-pages-preview

publish: site
	@printf 'Force-push %s/ to the gh-pages branch of origin? [y/N] ' $(SITE); read a; [ "$$a" = y ]
	tools/publish.sh $(SITE) gh-pages
