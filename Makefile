#####################
# General Variables #
#####################

GNU_ECHO := $(shell gecho --version 2>/dev/null)

ifdef GNU_ECHO
	ECHO=gecho
else
	ECHO=echo
endif


SRC=actes.tmp.tex $(wildcard */*.tex)
LATEX?=pdflatex
LFLAGS?=-halt-on-error

GSFLAGS=-sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -dEmbedAllFonts=true -dCompatibilityLevel=1.4 -dNOPAUSE -dBATCH -dSubsetFonts=true -dOptimize=true -dNOPLATFONTS -dDOPDFMARKS -dSAFER -dSTRICT -dConvertCMYKImagesToRGB=false -dProcessColorModel=/DeviceCMYK -dDetectDuplicateImages=true

BIB_MISSING = 'No file.*\.bbl|Citation.*undefined'
REFERENCE_UNDEFINED='(There were undefined references|Rerun to get (cross-references|the bars) right)'



###################
# Ebook Variables #
###################

HTLATEX=htlatex
HTFLAGS?="xhtml,charset=utf-8" " -cunihtf -utf8"

# ebook metadata
CALFLAGS+=--book-producer STIC --publisher STIC
CALFLAGS+=--series SSTIC2019 --language fr

# IMGPDFS=$(wildcard */img/*.pdf */img/**/*.pdf)
# IMGEPSS=$(foreach img, $(IMGPDFS), $(img:pdf=eps))
# IMGJPGS=$(wildcard */img/*.jpg */img/**/*.jpg)
# IMGPNGS=$(foreach img, $(IMGJPGS), $(img:jpg=png))



###################
# Generic targets #
###################

.PHONY: default export clean


default: Makefile.standalone-targets

export: Makefile.standalone-targets


clean:
	rm -f *.aux *.bbl *.blg *.idx *.ilg *.ind *.log *.toc
	rm -f _master.pdf
	rm -f _articles.tex Makefile.standalone-targets
	rm -f *.tmp.tex *.tmp.pdf
	rm -f *.ebook.tex *.ebook.css *.ebook.dvi *.ebook.html *.ebook.4ct *.ebook.4tc
	rm -f *.ebook.idv *.ebook.lg *.ebook.pdf *.ebook.tmp *.ebook.xref
	rm -f actes.pdf actes-online.pdf



#######################
# Compilation helpers #
#######################

%.tmp.pdf: %.tmp.tex sstic.cls llncs.cls
	@rm -f $(@:.pdf=.aux) $(@:.pdf=.idx)
	$(LATEX) $(LFLAGS) $<
	bibtex $(@:.pdf=.aux) > /dev/null || true
	makeindex $(@:.pdf=.idx) > /dev/null 2> /dev/null || true
	$(LATEX) $(LFLAGS) $< > /dev/null
	@grep -Eqc $(BIB_MISSING) $(@:.pdf=.log) && $(LATEX) $< > /dev/null ; true
	@grep -Eqc $(REFERENCE_UNDEFINED) $(@:.pdf=.log) && $(LATEX) $< > /dev/null; true
	-grep --color '\(Warning\|Overful\).*' $(@:.pdf=.log) || true

%.pdf: %.tmp.pdf
	gs -sOutputFile=$@ $(GSFLAGS) $< < /dev/null > /dev/null

%.tgz: %.pdf %
	@tar czf $@ $(@:.tgz=)/ $(@:.tgz=.pdf)
	@$(ECHO) "Created $@." >&2; \



#######################
# Proceedings targets #
#######################

actes-online.tmp.tex: _master.tex
	cp $< $@

actes-online.tmp.pdf: _articles.tex $(SRC)


actes.tmp.pdf: _articles.tex $(SRC)

actes.tmp.tex: _master.tex
	@sed 's/{sstic}/[paper]{sstic}/' $< > $@



#################
# Ebook helpers #
#################

%.eps: %.pdf
	pdftocairo -eps $< $@

# TODO: Re-add stg to protect from GS attacks (restricted policy.xml)
#%.png: %.jpg
#	convert $< $@

%.ebook.html: %.ebook.tex sstic.cls llncs.cls
	@rm -f $(@:.html=.aux)
	$(HTLATEX) $< $(HTFLAGS) > /dev/null
	bibtex $(@:.html=) ||true
	$(LATEX) $(LFLAGS) $(@:.html=.tex)
	$(HTLATEX) $< $(HTFLAGS) > /dev/null
	-grep --color '\(Warning\|Overful\).*' $(@:.html=.log)
	@grep -Eqc $(BIB_MISSING) $(@:.html=.log) && $(HTLATEX) $< $(HTFLAGS) > /dev/null ; true
	@grep -Eqc $(REFERENCE_UNDEFINED) $(@:.html=.log) && $(HTLATEX) $< $(HTFLAGS) > /dev/null; true


# TODO: Re-add a way to include authors metadata properly, if needed
# TODO: What about the title?
# -include article/metadata.mk
# AUTHORS?=SSTIC
# CALFLAGS+=--authors $(AUTHORS)

%.epub: %.ebook.html
	ebook-convert $< $@ $(CALFLAGS)

%.mobi: %.ebook.html
	ebook-convert $< $@ $(CALFLAGS)

%.azw3: %.epub
# ebook-convert doesn't rasterize svgs for azw3, but Kindle svg parser seems
# buggy, so instead of doing html -> azw3 we do html -> epub -> azw3.
	ebook-convert $< $@ $(CALFLAGS)



###############################
# Specific standalone targets #
###############################

_articles.tex: $(SRC) Makefile
	@for d in [^_]*/; do \
		i=$$(basename "$$d"); \
		check_i=$$($(ECHO) "$$i" | tr -cd "a-zA-Z0-9_+-"); \
		if [ "$$i" = "$$check_i" ]; then \
			$(ECHO) "\inputarticle{$$i}"; \
		fi; \
	done > $@

Makefile.standalone-targets: $(SRC) Makefile
	@for d in [^_]*/; do \
		i=$$(basename "$$d"); \
		check_i=$$($(ECHO) "$$i" | tr -cd "a-zA-Z0-9_+-"); \
		if [ "$$i" = "$$check_i" ]; then \
			$(ECHO) "# Targets for $$i"; \
			$(ECHO); \
			$(ECHO) "$$i.tmp.tex: _standalone.tex"; \
			$(ECHO) "	@sed 's/@@DIRECTORY@@/\$$(@:.tmp.tex=)/' _standalone.tex > \$$@"; \
			$(ECHO); \
			$(ECHO) "$$i.ebook.tex: $$i.tmp.tex"; \
			$(ECHO) "	@sed 's/{sstic}/[ebook]{sstic}/' \$$< > \$$@"; \
			$(ECHO); \
			$(ECHO) -n "$$i.tmp.pdf: $$i.tmp.tex $$($(ECHO) $$i/*.tex)"; \
			ls $$i/*.bib > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/*.bib)"; \
			ls $$i/img/*.jpg > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.jpg)"; \
			ls $$i/img/*.png > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.png)"; \
			ls $$i/img/*.eps > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.eps)"; \
			ls $$i/img/*.pdf > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.pdf)"; \
			$(ECHO); \
			$(ECHO); \
			$(ECHO) -n "$$i.ebook.html: $$i.ebook.tex $$($(ECHO) $$i/*.tex)"; \
			ls $$i/*.bib > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/*.bib)"; \
			ls $$i/img/*.jpg > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.jpg)"; \
			ls $$i/img/*.png > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.png)"; \
			ls $$i/img/*.eps > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.eps)"; \
			ls $$i/img/*.pdf > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.pdf)"; \
			$(ECHO); \
			$(ECHO); \
			$(ECHO) -n "actes.tmp.pdf: $$i.tmp.tex $$($(ECHO) $$i/*.tex)"; \
			ls $$i/*.bib > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/*.bib)"; \
			ls $$i/img/*.jpg > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.jpg)"; \
			ls $$i/img/*.png > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.png)"; \
			ls $$i/img/*.eps > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.eps)"; \
			ls $$i/img/*.pdf > /dev/null 2> /dev/null && $(ECHO) -n " $$($(ECHO) $$i/img/*.pdf)"; \
			$(ECHO); \
			$(ECHO); \
			$(ECHO) "$$i-clean:"; \
			$(ECHO) "	rm -f $$i.pdf $$i.azw3 $$i.epub $$i.mobi"; \
			$(ECHO); \
			$(ECHO) "default: $$i.pdf"; \
			$(ECHO) "clean: $$i-clean"; \
			$(ECHO) "export: $$i.tgz"; \
			$(ECHO) "Created targets for $$i." >&2; \
			$(ECHO); \
			$(ECHO); \
			$(ECHO); \
else \
			$(ECHO) "Ignoring invalid dir name ($$i)." >&2; \
		fi \
	done > Makefile.standalone-targets

-include Makefile.standalone-targets
