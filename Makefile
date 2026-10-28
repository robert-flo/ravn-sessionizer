SHAREDIR ?= /usr/share/ravn/sessionizer
BINDIR ?= /usr/bin
DESTDIR ?=

.PHONY: all install test lint check clean help

all: check

help:
	@echo "ravn-sessionizer targets:"
	@echo "  install  Install to $(DESTDIR)$(SHAREDIR) and symlink ravn-sessionizer to $(DESTDIR)$(BINDIR)"
	@echo "  test     Run the test suite"
	@echo "  lint     Run shellcheck on all bash scripts"
	@echo "  check    Run lint and test"

install:
	install -d "$(DESTDIR)$(BINDIR)"
	install -d "$(DESTDIR)$(SHAREDIR)/runtime/helper"
	install -d "$(DESTDIR)$(SHAREDIR)/runtime/lib"
	install -d "$(DESTDIR)$(SHAREDIR)/runtime/scripts"
	install -d "$(DESTDIR)$(SHAREDIR)/runtime/completion"
	install -m 755 ravn-sessionizer "$(DESTDIR)$(SHAREDIR)/ravn-sessionizer"
	install -m 644 herdr-plugin.toml "$(DESTDIR)$(SHAREDIR)/herdr-plugin.toml"
	install -m 644 sessionizer.conf.example "$(DESTDIR)$(SHAREDIR)/sessionizer.conf.example"
	install -m 644 runtime/commands.tsv "$(DESTDIR)$(SHAREDIR)/runtime/commands.tsv"
	install -m 644 runtime/helper/set_variable.sh "$(DESTDIR)$(SHAREDIR)/runtime/helper/set_variable.sh"
	install -m 644 runtime/lib/*.sh "$(DESTDIR)$(SHAREDIR)/runtime/lib/"
	install -m 755 runtime/scripts/* "$(DESTDIR)$(SHAREDIR)/runtime/scripts/"
	install -m 644 runtime/completion/ravn-sessionizer.bash "$(DESTDIR)$(SHAREDIR)/runtime/completion/ravn-sessionizer.bash"
	ln -sf "$(SHAREDIR)/ravn-sessionizer" "$(DESTDIR)$(BINDIR)/ravn-sessionizer"
	ln -sf "ravn-sessionizer" "$(DESTDIR)$(BINDIR)/rs"
	ln -sf "ravn-sessionizer" "$(DESTDIR)$(BINDIR)/ri"

lint:
	shellcheck -x ravn-sessionizer runtime/scripts/* runtime/lib/*.sh runtime/helper/*.sh runtime/completion/*.bash tests/*.sh tests/stubs/*

test:
	bash tests/run.sh

check: lint test

clean:
	rm -rf dest
