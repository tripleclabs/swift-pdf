# swift-pdf dev tasks.
#
# On macOS, Homebrew's pkg-config files for harfbuzz live under the brew prefix,
# so PKG_CONFIG_PATH must point there for the CHarfBuzz system-library target to
# resolve. On Linux the .pc files are on the default path and this is a no-op.

BREW := $(shell command -v brew >/dev/null 2>&1 && brew --prefix)
export PKG_CONFIG_PATH := $(BREW)/lib/pkgconfig:$(BREW)/opt/harfbuzz/lib/pkgconfig:$(PKG_CONFIG_PATH)

.PHONY: build test samples clean

build:
	swift build

test:
	swift test

samples:
	swift run samples

clean:
	swift package clean
