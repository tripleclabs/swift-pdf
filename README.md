# swift-pdf

A pure-Swift PDF generation library for Linux and macOS. No libharu.

> **Status: `0.1.0` MVP feature-complete.** Multi-page documents, vector
> graphics, the 14 standard fonts plus embedded/subset TTF/OTF, PNG & JPEG
> images, and Flate compression — all validated against PDFKit.

## Features

- **Documents** — multi-page, page sizes/orientation, `/Info` metadata
- **Vector graphics** — paths (lines, Béziers, rects, ellipses), fill/stroke/clip
  (nonzero + even-odd), RGB/CMYK/Gray colour, line attributes, dashes, transforms,
  scoped graphics state
- **Text** — the 14 standard fonts with correct metrics and full **WinAnsi
  (Latin-1 / cp1252)** support (German, French, Spanish, €, smart quotes), and **embedded TTF/OTF**
  fonts (HarfBuzz shaping + subsetting, Type0/CIDFontType2, `/ToUnicode` so text
  stays selectable/searchable)
- **Images** — PNG (with alpha → `/SMask`) and JPEG (DCTDecode passthrough)
- **Compression** — FlateDecode stream compression

Try it: `swift run samples` writes showcase PDFs into `Samples/`.

## Design

- **`PDFCore`** is pure Swift with **zero native dependencies** — the base-14
  text + vector-graphics path needs no system libraries. It implements the PDF
  object model and file structure directly against ISO 32000.
- Optional capability layers link well-maintained system libraries rather than
  vendoring them:
  - **HarfBuzz** (MIT) — text shaping + font subsetting for embedded fonts
  - **libpng** — PNG decoding
  - **zlib** — Flate stream compression
- Install on Linux: `apt install libharfbuzz-dev libpng-dev zlib1g-dev`
  · on macOS: `brew install harfbuzz libpng`

## License

MIT. A small set of data tables under `Sources/PDFCore/LibHaruDerived/` are
derived from libharu and carry its permissive notice; see [LICENSE](LICENSE).
