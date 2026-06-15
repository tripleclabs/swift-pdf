# swift-pdf

A pure-Swift PDF generation library for Linux and macOS. No libharu.

> **Status: early development.** Building toward a `0.1.0` MVP (multi-page vector
> graphics, base-14 and embedded TTF/OTF fonts, PNG/JPEG images, Flate
> compression). Currently at the M1 core foundation.

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
