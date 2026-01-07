# kctl-env Makefile
# Install/uninstall to system paths; no external deps

PREFIX ?= /usr/local
LIBDIR := $(PREFIX)/lib/kctl-env
BINDIR := $(PREFIX)/bin
# Project semantic version from VERSION file
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.1.0)

.PHONY: all install uninstall dist clean release

all:
	@echo "Nothing to build; scripts only"

install:
	install -d "$(DESTDIR)$(LIBDIR)/bin" "$(DESTDIR)$(LIBDIR)/libexec"
	install -m 0755 bin/kctl-env "$(DESTDIR)$(LIBDIR)/bin/kctl-env"
	install -m 0755 bin/kubectl "$(DESTDIR)$(LIBDIR)/bin/kubectl"
	install -m 0755 libexec/* "$(DESTDIR)$(LIBDIR)/libexec/"
	install -d "$(DESTDIR)$(BINDIR)"
	ln -sf "$(LIBDIR)/bin/kctl-env" "$(DESTDIR)$(BINDIR)/kctl-env"
	ln -sf "$(LIBDIR)/bin/kubectl" "$(DESTDIR)$(BINDIR)/kubectl"
	@echo "Installed to $(DESTDIR)$(PREFIX)"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/kctl-env" "$(DESTDIR)$(BINDIR)/kubectl"
	rm -rf "$(DESTDIR)$(LIBDIR)"
	@echo "Uninstalled from $(DESTDIR)$(PREFIX)"

# Create a tarball release of the scripts (excluding runtime dirs)
dist:
	mkdir -p dist
	git ls-files | grep -vE '^(cache/|tmp/|versions/|testhome/)' | tar -czf dist/kctl-env-$(VERSION).tar.gz -T -
	@echo "Created dist/kctl-env-$(VERSION).tar.gz"

clean:
	rm -rf dist

# Prepare a release by updating VERSION and packaging metadata, and committing changes.
# Usage: make release V=0.1.1
release:
	@if [ -z "$(V)" ]; then echo "Missing V. Usage: make release V=0.1.1" >&2; exit 1; fi
	@./scripts/release.sh "$(V)"
