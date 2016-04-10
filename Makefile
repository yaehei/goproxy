RELEASE = r$(shell git rev-list HEAD | wc -l | xargs)

PACKAGE = goproxy
REPO = $(shell git rev-parse --show-toplevel)
SOURCEDIR = $(REPO)/
BUILDDIR = $(REPO)/build
STAGEDIR = $(BUILDDIR)/stage
OBJECTDIR = $(BUILDDIR)/obj
DISTDIR = $(BUILDDIR)/dist

GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

ifeq ($(GOOS), windows)
	GOPROXY_EXE = $(PACKAGE).exe
	GOPROXY_STAGEDIR = $(STAGEDIR)
	GOPROXY_DISTCMD = 7za a -y -t7z -mx=9 -m0=lzma -mfb=64 -md=32m -ms=on
	GOPROXY_DISTEXT = .7z
else ifeq ($(GOOS), darwin)
	GOPROXY_EXE = $(PACKAGE)
	GOPROXY_STAGEDIR = $(STAGEDIR)
	GOPROXY_DISTCMD = BZIP=-9 tar cvjpf
	GOPROXY_DISTEXT = .tar.bz2
else
	GOPROXY_EXE = $(PACKAGE)
	GOPROXY_STAGEDIR = $(STAGEDIR)/goproxy
	GOPROXY_DISTCMD = XZ_OPT=-9 tar cvJpf
	GOPROXY_DISTEXT = .tar.xz
endif

OBJECTS :=
OBJECTS += $(OBJECTDIR)/$(GOPROXY_EXE)

SOURCES :=
SOURCES += $(REPO)/README.md
SOURCES += $(SOURCEDIR)/main.json
SOURCES += $(wildcard $(REPO)/httpproxy/filters/*/*.json)
#SOURCES += $(SOURCEDIR)/goproxy.pem
SOURCES += $(REPO)/httpproxy/filters/autoproxy/gfwlist.txt

ifeq ($(GOOS), windows)
	SOURCES += $(REPO)/assets/gui/goproxy-gui.exe
	SOURCES += $(REPO)/assets/certmgr/certmgr.exe
	SOURCES += $(REPO)/assets/startup/addto-startup.vbs
else ifeq ($(GOOS), darwin)
	SOURCES += $(REPO)/assets/gui/goproxy-osx.command
else ifeq ($(GOOS)_$(GOARCH), linux_amd64)
	SOURCES += $(REPO)/assets/gui/goproxy-gtk.py
	SOURCES += $(REPO)/assets/systemd/goproxy.service
	SOURCES += $(REPO)/assets/systemd/goproxy-cleanlog.service
	SOURCES += $(REPO)/assets/systemd/goproxy-cleanlog.timer
else
	SOURCES += $(REPO)/assets/gui/goproxy-gtk.py
	SOURCES += $(REPO)/assets/startup/goproxy.sh
endif

LDFLAGS = -X main.version=$(RELEASE)

ifneq (,$(findstring mips,$(GOARCH)))
	LDFLAGS += -s
endif

.PHONY: build
build: $(DISTDIR)/$(PACKAGE)_$(GOOS)_$(GOARCH)-$(RELEASE)$(GOPROXY_DISTEXT)
	mv $< $(shell echo $< | sed 's/_darwin_/_macosx_/') || true
	ls -lht $(DISTDIR)

.PHONY: clean
clean:
	$(RM) -rf $(BUILDDIR)

$(DISTDIR)/$(PACKAGE)_$(GOOS)_$(GOARCH)-$(RELEASE)$(GOPROXY_DISTEXT): $(OBJECTS)
	mkdir -p $(DISTDIR)
	mkdir -p $(GOPROXY_STAGEDIR)/ && \
	cp $(OBJECTDIR)/$(GOPROXY_EXE) $(GOPROXY_STAGEDIR)/$(GOPROXY_EXE)
	for f in $(SOURCES) ; do cp $$f $(GOPROXY_STAGEDIR)/ ; done
	cd $(STAGEDIR) && $(GOPROXY_DISTCMD) $@ *

$(OBJECTDIR)/$(GOPROXY_EXE):
	mkdir -p $(OBJECTDIR)
	go build -v -ldflags="$(LDFLAGS)" -o $@ .
