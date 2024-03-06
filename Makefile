all: site

MKDOCS_VER = 9.5.9

# serve the site locally using mkdocs-material insiders container and dirty-reload
# in this mode navigation might not update properly, but the content will be updated
# if nav is not updated, re-run the target.
.PHONY: serve-docs
serve-docs:
	docker run -it --rm -p 8000:8000 -v $(CURDIR):/docs ghcr.io/squidfunk/mkdocs-material:$(MKDOCS_VER) serve -a 0.0.0.0:8000 --dirtyreload

.PHONY: site
site:
	docker run -it --rm -p 8000:8000 -v $(CURDIR):/docs ghcr.io/squidfunk/mkdocs-material:$(MKDOCS_VER)