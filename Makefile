# Install layout shared by every package (debian/, packaging/) and usable on its own:
#   make install PREFIX=/usr DESTDIR=/tmp/pkg
# install.sh is the per-user alternative that installs to ~/.local instead.

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
UDEVDIR ?= $(PREFIX)/lib/udev/rules.d
MANDIR ?= $(DATADIR)/man

APP_ID = io.github.mfat.StudioBrightness
SCRIPTS = studio-brightness studio-brightness-gui studio-brightness-osd

all:

install:
	for f in $(SCRIPTS); do install -Dm755 $$f $(DESTDIR)$(BINDIR)/$$f; done
	install -Dm644 data/$(APP_ID).desktop $(DESTDIR)$(DATADIR)/applications/$(APP_ID).desktop
	install -Dm644 data/icons/$(APP_ID).svg $(DESTDIR)$(DATADIR)/icons/hicolor/scalable/apps/$(APP_ID).svg
	install -Dm644 data/icons/$(APP_ID)-symbolic.svg $(DESTDIR)$(DATADIR)/icons/hicolor/symbolic/apps/$(APP_ID)-symbolic.svg
	install -Dm644 data/$(APP_ID).metainfo.xml $(DESTDIR)$(DATADIR)/metainfo/$(APP_ID).metainfo.xml
	for f in $(SCRIPTS); do install -Dm644 data/$$f.1 $(DESTDIR)$(MANDIR)/man1/$$f.1; done
	install -Dm644 data/70-studio-brightness.rules $(DESTDIR)$(UDEVDIR)/70-studio-brightness.rules

check:
	for f in $(SCRIPTS); do python3 -m py_compile $$f || exit 1; done
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
	desktop-file-validate data/$(APP_ID).desktop
	appstreamcli validate --no-net data/$(APP_ID).metainfo.xml
	bash -n install.sh

.PHONY: all install check
