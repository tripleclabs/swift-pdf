# swift-pdf

A pure-Swift PDF generation library for **Linux and macOS**. No libharu, no C
PDF engine to vendor — it writes PDF directly against the ISO 32000 spec, and
links only well-maintained system libraries (HarfBuzz, libpng, zlib) for the
parts worth not reinventing.

> **Status:** `0.1.0` — feature-complete MVP, validated against a real
> production consumer (rendered output is pixel-faithful to the previous
> libharu-backed engine). See [Roadmap](#roadmap) for what's next.

## Why

It replaces a Swift wrapper around [libharu](https://github.com/libharu/libharu),
a C PDF library whose own maintainers describe it as needing a new maintainer.
`swift-pdf` owns the engine outright in memory-safe Swift, so there's no
abandoned C dependency to carry — and the base-14 text + vector-graphics path
has **zero native dependencies** at all.

## Features

- **Documents** — multi-page, standard & custom page sizes, orientation, `/Info` metadata
- **Vector graphics** — paths (lines, cubic Béziers, rectangles, ellipses),
  fill / stroke / clip (nonzero + even-odd), RGB / CMYK / Gray colour, line
  width / cap / join / dash, affine transforms, scoped graphics state
- **Text**
  - the 14 standard fonts with correct Adobe metrics
  - full **WinAnsi (Latin-1 / cp1252)** — German, French, Spanish, €, smart quotes
  - **embedded TTF/OTF** via HarfBuzz: shaping + glyph subsetting, Type0 /
    CIDFontType2, `/ToUnicode` (so text stays selectable & searchable)
  - text measurement and single-line alignment helpers
- **Images** — PNG (with alpha → `/SMask`) via libpng, JPEG via DCTDecode passthrough
- **Compression** — FlateDecode stream compression (zlib)

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/tripleclabs/swift-pdf.git", from: "0.1.0")
```

```swift
.product(name: "SwiftPDF", package: "swift-pdf")
```

### Native dependencies

The pure-Swift core needs nothing. The optional capability layers link system
libraries — install them only if you use fonts/images/compression:

| Platform | Command |
|---|---|
| **Linux (Debian/Ubuntu)** | `apt install libharfbuzz-dev libpng-dev zlib1g-dev pkg-config` |
| **macOS (Homebrew)** | `brew install harfbuzz libpng pkg-config` |

On macOS, set `PKG_CONFIG_PATH` so SwiftPM finds Homebrew's `.pc` files (the
included `Makefile` does this for you):

```sh
export PKG_CONFIG_PATH="$(brew --prefix)/lib/pkgconfig:$(brew --prefix harfbuzz)/lib/pkgconfig:$(brew --prefix libpng)/lib/pkgconfig"
```

## Quick start

```swift
import SwiftPDF

let doc = PDFDocument(metadata: PDFMetadata(title: "Hello", author: "You"))
doc.useFlateCompression()                       // optional (links zlib)

let page = doc.addPage(size: .a4)
page.draw { ctx in
    // Vector graphics
    ctx.setFillColor(.rgb(red: 0.2, green: 0.45, blue: 0.95))
    ctx.fill(Path.rect(x: 60, y: 760, width: 200, height: 4))

    // Standard-14 text (Latin-1 works)
    ctx.setFont(.helveticaBold, size: 24)
    ctx.show("Grüße aus swift-pdf", at: Point(x: 60, y: 720))

    // Aligned single line in a box
    ctx.setFont(.helvetica, size: 10)
    ctx.show("right-aligned", in: Rectangle(x: 60, y: 700, width: 475, height: 12),
             alignment: .right)
}

try doc.data().write(to: URL(fileURLWithPath: "out.pdf"))
```

Embedding a font and an image:

```swift
let font = try TrueTypeFont(data: Data(contentsOf: fontURL))
let image = try PDFImageLoader.png(Data(contentsOf: pngURL))

page.draw { ctx in
    ctx.setFont(font, size: 18)
    ctx.show("Embedded & subset", at: Point(x: 60, y: 660))
    ctx.draw(image, in: Rectangle(x: 60, y: 480, width: 160, height: 160))
}
```

See `Sources/samples/` for a fuller showcase: `swift run samples` writes
example PDFs (fonts, graphics, transforms, a multi-page report) into `Samples/`.

## Architecture

Layered so the pure-Swift core never links C:

| Module | Role | Native dep |
|---|---|---|
| `PDFCore` | COS model, writer, document/pages, graphics, base-14 text, value types | **none** |
| `PDFFlate` | FlateDecode compression | zlib |
| `PDFFonts` | TTF/OTF load, shape, subset, embed | HarfBuzz |
| `PDFImage` | PNG decode, JPEG passthrough | libpng |
| `SwiftPDF` | umbrella — import this | (re-exports the above) |

You can depend on `PDFCore` alone for a fully dependency-free build (base-14
text + vector graphics).

## Building & testing

```sh
make build      # swift build
make test       # swift test  (sets PKG_CONFIG_PATH on macOS)
make samples    # swift run samples
```

## Requirements

- **Swift 6.3+**
- **Linux** — the primary target (server-side PDF generation); **x86_64 and arm64**
- **macOS 26+** — development & CI

## Roadmap

See [ROADMAP.md](ROADMAP.md). Near-term: hyperlinks/annotations, outlines,
stream compression for fonts/images, page labels, richer text controls. Later:
shadings/gradients, encryption, a reusable layout layer, and more.

## License

MIT — see [LICENSE](LICENSE). © Triple C Labs GmbH. All original work; the
base-14 font width tables are factual metrics transcribed from the URW base-35
AFMs (metric-compatible with the Adobe Core-14 standard fonts).
