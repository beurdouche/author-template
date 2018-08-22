SRC=actes.tmp.tex $(wildcard */*.tex)
LATEX?=pdflatex
LFLAGS?=-halt-on-error

GSFLAGS=-sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -dEmbedAllFonts=true -dCompatibilityLevel=1.6

BIB_MISSING = 'No file.*\.bbl|Citation.*undefined'
REFERENCE_UNDEFINED='(There were undefined references|Rerun to get (cross-references|the bars) right)'


# # ebook variables

# FINALHTML=$(FINALPDF:pdf=html)
# FINALEPUB=$(FINALHTML:html=epub)
# FINALAZW3=$(FINALHTML:html=azw3)
# FINALMOBI=$(FINALHTML:html=mobi)
# SRCEBK=$(MASTER)-ebook.tex $(wildcard */*.tex)
# HTLATEX=htlatex
# HTFLAGS?="xhtml,charset=utf-8" " -cunihtf -utf8"

# # ebook metadata
# CALFLAGS+=--book-producer STIC --publisher STIC
# CALFLAGS+=--series SSTIC2019 --language fr
# -include article/metadata.mk
# AUTHORS?=SSTIC
# CALFLAGS+=--authors $(AUTHORS)

# IMGPDFS=$(wildcard */img/*.pdf */img/**/*.pdf)
# IMGEPSS=$(foreach img, $(IMGPDFS), $(img:pdf=eps))
# IMGJPGS=$(wildcard */img/*.jpg */img/**/*.jpg)
# IMGPNGS=$(foreach img, $(IMGJPGS), $(img:jpg=png))



.PHONY: default export clean


# Generic targets
default: Makefile.standalone-targets

export: Makefile.standalone-targets


clean:
	rm -f *.aux *.bbl *.blg *.idx *.ilg *.ind *.log *.toc
	rm -f _master.pdf
	rm -f _articles.tex Makefile.standalone-targets
	rm -f *.tmp.tex *.tmp.pdf
	rm -f *.ebook.tex *.ebook.css *.ebook.dvi *.ebook.html


%.tmp.pdf: %.tmp.tex sstic.cls llncs.cls
	@rm -f $(@:.pdf=.aux) $(@:.pdf=.idx)
	$(LATEX) $(LFLAGS) $< > /dev/null
	bibtex $(@:.pdf=.aux) > /dev/null || true
	$(LATEX) $(LFLAGS) $< > /dev/null
	makeindex $(@:.pdf=.idx) > /dev/null 2> /dev/null || true
	@grep -Eqc $(BIB_MISSING) $(@:.pdf=.log) && $(LATEX) $< > /dev/null ; true
	@grep -Eqc $(REFERENCE_UNDEFINED) $(@:.pdf=.log) && $(LATEX) $< > /dev/null; true
	-grep --color '\(Warning\|Overful\).*' $(@:.pdf=.log) || true

%.pdf: %.tmp.pdf
	gs -sOutputFile=$@ $(GSFLAGS) $< < /dev/null > /dev/null

%.tgz: %.pdf %
	@tar czf $@ $(@:.tgz=)/ $(@:.tgz=.pdf)
	@echo "Created $@." >&2; \


# Helpers for generic targets

actes.tmp.tex: _master.tex
	cp $< $@

actes.tmp.pdf: _articles.tex $(SRC)



# Specific standalone targets

_articles.tex:
	@for d in [^_]*/; do \
		i=$$(basename "$$d"); \
		check_i=$$(echo "$$i" | tr -cd "a-zA-Z0-9_+-"); \
		if [ "$$i" = "$$check_i" ]; then \
			echo "\inputarticle{$$i}"; \
		fi; \
	done > $@

Makefile.standalone-targets:
	@for d in [^_]*/; do \
		i=$$(basename "$$d"); \
		check_i=$$(echo "$$i" | tr -cd "a-zA-Z0-9_+-"); \
		if [ "$$i" = "$$check_i" ]; then \
			echo "$$i.tmp.tex: _standalone.tex"; \
			echo "	@sed 's/@@DIRECTORY@@/\$$(@:.tmp.tex=)/' _standalone.tex > \$$@"; \
			echo; \
			echo "$$i.ebook.tex: $$i.tmp.tex"; \
			echo "	@sed 's/{sstic}/[ebook]{sstic}/' \$$< > \$$@"; \
			echo; \
			echo -n "$$i.tmp.pdf: $$i.tmp.tex $$(echo $$i/*.tex)"; \
			ls $$i/*.bib > /dev/null 2> /dev/null && echo -n " $$(echo $$i/*.bib)"; \
			ls $$i/img/*.png > /dev/null 2> /dev/null && echo -n " $$(echo $$i/img/*.png)"; \
			ls $$i/img/*.eps > /dev/null 2> /dev/null && echo -n " $$(echo $$i/img/*.eps)"; \
			ls $$i/img/*.pdf > /dev/null 2> /dev/null && echo -n " $$(echo $$i/img/*.pdf)"; \
			echo; \
			echo; \
			echo -n "actes.tmp.pdf: $$i.tmp.tex $$(echo $$i/*.tex)"; \
			ls $$i/*.bib > /dev/null 2> /dev/null && echo -n " $$(echo $$i/*.bib)"; \
			ls $$i/img/*.png > /dev/null 2> /dev/null && echo -n " $$(echo $$i/img/*.png)"; \
			ls $$i/img/*.eps > /dev/null 2> /dev/null && echo -n " $$(echo $$i/img/*.eps)"; \
			ls $$i/img/*.pdf > /dev/null 2> /dev/null && echo -n " $$(echo $$i/img/*.pdf)"; \
			echo; \
			echo; \
			echo "$$i.pdf: $$i.tmp.pdf"; \
			echo "	gs -sOutputFile=\$$@ $(GSFLAGS) $$< < /dev/null > /dev/null"; \
			echo; \
			echo "default: $$i.pdf"; \
			echo "export: $$i.tgz"; \
			echo "Created targets for $$i." >&2; \
			echo; \
		else \
			echo "Ignoring invalid dir name ($$i)." >&2; \
		fi \
	done > Makefile.standalone-targets

-include Makefile.standalone-targets




# # ebook targets

# $(FINALHTML): $(SRCEBK) $(IMGPNGS) $(IMGEPSS)
# 	$(HTLATEX) $(MASTER)-ebook.tex $(HTFLAGS)
# 	make LATEX=$(HTLATEX) LFLAGS="" $(MASTER)-ebook.bbl
# 	make full-ebook
# 	mv $(MASTER)-ebook.html $(FINALHTML)

# full-ebook: $(MASTER)-ebook.ind
# 	$(HTLATEX) $(MASTER)-ebook.tex $(HTFLAGS)
# 	-grep --color '\(Warning\|Overful\).*' $(MASTER)-ebook.log
# 	@grep -Eqc $(BIB_MISSING) $(MASTER)-ebook.log && $(HTLATEX) $(MASTER)-ebook.tex $(HTFLAGS) > /dev/null ; true
# 	@grep -Eqc $(REFERENCE_UNDEFINED) $(MASTER)-ebook.log && $(HTLATEX) $(MASTER)-ebook.tex $(HTFLAGS) > /dev/null; true

# %.bbl:
# 	bibtex $(@:.bbl=) ||true
# 	$(LATEX) $(LFLAGS) $(@:.bbl=.tex)

# %.ind:
# 	makeindex $(@:.ind=)

# %.eps: %.pdf
# 	pdftocairo -eps $< $@

# %.png: %.jpg
# 	convert $< $@

# $(IMGPNGS): $(IMGJPGS)
# $(IMGEPSS): $(IMGPDFS)

# %.epub: %.html
# 	ebook-convert $< $@ $(CALFLAGS)

# %.mobi: %.html
# 	ebook-convert $< $@ $(CALFLAGS)

# %.azw3: %.epub
# 	# ebook-convert doesn't rasterize svgs for azw3, but Kindle svg parser seems
# 	# buggy, so instead of doing html -> azw3 we do html -> epub -> azw3.
# 	ebook-convert $< $@ $(CALFLAGS)
