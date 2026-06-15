# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- GitHub Actions CI (Linux amd64 + arm64 full, Linux `PDFCore`-only, macOS).

### Changed
- Require **Swift 6.3+** (Swift 6 language mode) and **macOS 26+**.

## [0.1.0]

First release: a pure-Swift PDF generation library replacing the libharu-backed
engine, validated against a real production consumer (pixel-faithful output).

### Added
- **PDFCore** (zero native dependencies): COS object model and file writer
  (ISO 32000-1 §7.3/§7.5), `PDFDocument`/`PDFPage`/`PDFPageSize`/`PDFMetadata`,
  geometry value types (`Point`/`Size`/`Rectangle`/`AffineTransform`), `PDFColor`,
  `Path`, and a `DrawingContext` for paths, fills/strokes, clipping, colour,
  line attributes, dashes, transforms, and graphics-state save/restore.
- **Text**: the 14 standard fonts with correct Adobe metrics; full WinAnsi
  (Latin-1 / cp1252) encoding incl. German/French/Spanish, €, and smart quotes;
  text measurement and aligned single-line `show(_:in:alignment:)`.
- **PDFFonts** (HarfBuzz): TTF/OTF loading, shaping, glyph subsetting
  (`RETAIN_GIDS`), and Type0/CIDFontType2 embedding with `/ToUnicode`.
- **PDFImage** (libpng): PNG decoding with alpha → `/SMask`; JPEG embedding via
  DCTDecode passthrough.
- **PDFFlate** (zlib): FlateDecode stream compression.
- `samples` CLI showcasing the feature set.
