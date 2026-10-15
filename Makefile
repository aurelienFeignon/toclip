PREFIX ?= /usr/local
DESTDIR ?=
BINDIR = $(DESTDIR)$(PREFIX)/bin
LIBDIR = $(DESTDIR)$(PREFIX)/lib/toclip
.PHONY: install uninstall test lint
install:
	install -d "$(BINDIR)" "$(LIBDIR)"
	install -m 755 bin/toclip "$(BINDIR)/toclip"
	install -m 644 lib/*.sh "$(LIBDIR)/"
uninstall:
	rm -f "$(BINDIR)/toclip" "$(LIBDIR)/detect.sh" "$(LIBDIR)/native.sh" "$(LIBDIR)/osc52.sh"
	-rmdir "$(LIBDIR)"
test:
	bats tests/*.bats
lint:
	shellcheck -x -P . bin/toclip lib/*.sh tests/integration/*.sh
