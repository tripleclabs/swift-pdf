// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// An embeddable font (e.g. a HarfBuzz-backed TrueType/OpenType face),
/// implemented outside PDFCore so the core stays free of native dependencies.
///
/// The drawing context calls `encode` to turn text into content-stream operand
/// bytes (accumulating the glyphs it uses), and at document finalize the
/// document calls `buildFontObject` to subset and emit the font into the file.
public protocol EmbeddedFont: AnyObject {
    /// Stable identity for per-document resource/object deduplication.
    var fontKey: String { get }

    /// Whether `encode`'s operand is a hex string `<…>` (Type0 glyph ids) rather
    /// than a literal string `(…)`.
    var usesHexString: Bool { get }

    /// Encode `text` into content-stream operand bytes, recording the glyphs
    /// used (for later subsetting), and return the advance width in points.
    func encode(_ text: String, size: Double) -> (operand: [UInt8], width: Double)

    /// Advance width of `text` at `size` points, with no side effects.
    func width(of text: String, size: Double) -> Double

    /// Ascent (distance from baseline to top) at `size` points.
    func ascent(forSize size: Double) -> Double

    /// Subset and emit this font into `writer`, returning the `/Font`
    /// dictionary's object number. Called once per document.
    func buildFontObject(into writer: PDFWriter) -> Int
}
