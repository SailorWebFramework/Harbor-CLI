# Taken from http://csl.cool/2023/10/27/ios-dev/upload-a-cli-tool-written-in-swift-to-homebrew/

prefix ?= /usr/local
bindir = $(prefix)/bin

BUILDDIR = $(REPODIR)/.build

build:
	swift build -c release --disable-sandbox

install: build
	install -d "$(bindir)"
	install ".build/release/harbor" "$(bindir)"

uninstall:
	$(RM) -rf "$(bindir)/harbor"

clean:
	$(RM) -rf .build

.PHONY: build install uninstall clean
