# Roadmap

Where swift-pdf is headed after `0.1.0`. This is a living document — priorities
will shift with real usage. Items are grouped by horizon, with a rough sense of
effort (S/M/L) and risk where useful.

## Where 0.1.0 stands

Feature-complete MVP, validated pixel-faithfully against a real production
consumer (swift-xmlpdf):

- multi-page documents, metadata
- vector graphics (paths, fill/stroke/clip, RGB/CMYK/Gray, line attrs, dashes,
  transforms, graphics-state save/restore)
- the 14 standard fonts with full **WinAnsi / Latin-1** (German, French, …)
- **embedded TTF/OTF** via HarfBuzz (shaping, subsetting, Type0/CIDFontType2,
  `/ToUnicode`)
- PNG (with alpha → `/SMask`) and JPEG images
- FlateDecode compression

## Guiding principles

These shaped 0.1 and should keep shaping what comes next:

1. **`PDFCore` stays dependency-free.** The base-14 text + vector-graphics path
   must always build with zero native libraries. New native deps go in their own
   isolated capability module behind a `PDFCore` protocol seam.
2. **Own the engine; link healthy libs.** Implement against ISO 32000 ourselves;
   link well-maintained system libraries (HarfBuzz, libpng, zlib) rather than
   vendoring. Never re-introduce an abandoned C dependency.
3. **Validate against real output**, not a reference implementation — structural
   checks + an independent renderer (PDFKit) + visual review. No coupling our
   tests to another PDF engine.
4. **Additive, semantically-versioned API.** Prefer non-breaking growth.

---

## Near-term (0.2.x candidates)

High value, well-scoped, mostly build on what's already there.

- **Hyperlinks & link annotations** — `/Annots` with `/Link` + URI/GoTo actions.
  The most-requested "missing" feature for real documents. **S–M.**
- **Outlines / bookmarks** — a document outline tree for multi-page navigation. **S–M.**
- **Compress embedded font & image streams** — `FontFile2` and raw image samples
  are currently emitted uncompressed; route them through the document compressor
  (Flate) for meaningfully smaller files. **S.**
- **Page labels** — roman/letter/decimal numbering styles (`/PageLabels`). **S.**
- **Richer text controls** — character/word spacing, text rise, horizontal
  scaling, render modes (stroke/clip text). Mostly thin content-stream operators. **S.**
- **DocC documentation + more examples** — the public API is already doc-commented;
  generate and publish DocC, expand `Samples/`. **S.**

## Medium-term

- **Shadings & patterns** — axial/radial gradients (`/Shading`), tiling patterns.
  Unlocks a lot of design polish. **M.**
- **Encryption & permissions** — standard security handler (RC4 R2/R3 and AES-128/256),
  owner/user passwords, permission flags. **Security-sensitive: use `swift-crypto`
  for the primitives rather than hand-rolling MD5/RC4/AES.** **M, higher risk.**
- **Better image support** — indexed/palette PNG (smaller output), grayscale, CMYK
  JPEG, 16-bit, and an image-interpolation flag. Possibly add a generic
  `PDFImageData` ingestion path so callers can supply pre-decoded samples. **M.**
- **Color management** — ICC-based color spaces (`/ICCBased`), separation/spot
  colors, named colors. **M.**
- **Transparency** — constant alpha + blend modes via `ExtGState`, soft masks for
  graphics, transparency groups. **M.**
- **Layout primitives (`SwiftPDFLayout` product)** — extract the *generic* box /
  flow / measurement engine (the reusable part of swift-xmlpdf's layout) into an
  optional product of this package. Keeps app-specific concerns (XML templating,
  barcodes, QR, element vocabularies) in downstream libraries while sharing the
  measure-and-place core. **No new third-party deps** — it builds only on `PDFCore`.
  See "Notes" below. **M.**

## Longer-term / exploratory

- **Tagged PDF / accessibility (PDF/UA)** and **PDF/A** archival conformance.
  Important for some regulated/enterprise use; significant structural work. **L.**
- **Object streams & cross-reference streams (PDF 1.5+)** — smaller files and a
  cleaner writer; a fair bit of writer rework. **M–L.**
- **Streaming / incremental output** — write very large documents without holding
  the whole object graph in memory. **L.**
- **Complex-script & vertical text** — HarfBuzz already shapes RTL/complex scripts;
  this is about bidi ordering, proper run handling, and vertical writing modes
  surfaced through the API. **M–L.**
- **Bundled convenience fonts** — optionally ship the URW base-35 (or another
  open family) as ready-to-embed fonts so callers get good typography without
  supplying font files. Note the URW license (AGPL + font-embedding exception);
  keep it an opt-in module. **S, licensing review.**
- **Linux system-font discovery** — resolve font names to files via fontconfig,
  so callers can ask for "DejaVu Sans" without shipping the file. **M.**

## Explicitly out of scope (for now)

- **Reading / parsing / editing existing PDFs.** swift-pdf is a *generator*. A
  parser is a large, separate undertaking; merging/stamping existing PDFs would
  need one.
- **3D (U3D/PRC), multimedia, JavaScript actions.** Niche; high surface area.
- **CJK *standard* encodings / predefined CID fonts.** Largely unnecessary in our
  design: we embed + subset fonts via HarfBuzz, which already shapes CJK, so the
  giant predefined-CMap lookup tables libharu carried aren't needed. (Embedded CJK
  *fonts* already work today.)

## Cross-cutting / quality

- **Fuzz-test the parsers** — the JPEG SOF parser and (via libpng) PNG ingestion
  take untrusted bytes; add fuzzing/malformed-input tests.
- **Benchmarks** — track output size and generation time across releases.
- **Broaden edge-case coverage** — degenerate paths, empty docs, very large pages,
  unusual font tables (CFF/OTF embedding has a `FontFile3` branch worth more tests).

## Notes

- **The layout-vs-engine split** (why swift-xmlpdf stays separate): folding an
  app-shaped layer into swift-pdf would drag its dependencies (`QRCodeGenerator`,
  `DataXML`) into every consumer's dependency graph and blur the engine's scope.
  The reusable part is the *generic* layout core, which can come *down* into
  swift-pdf as `SwiftPDFLayout` — without those deps — if and when it proves
  general enough.
- **Encryption caveat:** prefer audited crypto (`swift-crypto`) over porting C
  implementations of MD5/RC4/AES. The value is the PDF security-handler plumbing,
  not the primitives.
