// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// A single page in a document. In M2 a page carries its size and a content
/// byte buffer; the drawing API (M3) appends content-stream operators to it,
/// and font/image resources (M4/M6/M7) attach here too.
public final class PDFPage {
    /// The page size in points (MediaBox is `[0 0 width height]`).
    public var size: PDFPageSize

    /// Raw content-stream bytes. Populated by the drawing context in later
    /// milestones; an empty buffer yields a valid (blank) page.
    var content: [UInt8] = []

    /// A font referenced by a page: either a standard-14 font or an embedded one.
    enum FontRef {
        case standard(StandardFont)
        case embedded(EmbeddedFont)
    }

    /// Fonts referenced by this page, in resource order (`F1`, `F2`, …).
    private(set) var fonts: [(name: String, font: FontRef)] = []
    private var resourceNameByKey: [String: String] = [:]

    init(size: PDFPageSize) {
        self.size = size
    }

    /// Resource name (`F1`, `F2`, …) for a standard font, registering on first use.
    func resourceName(for font: StandardFont) -> String {
        register(key: "std:" + font.baseName) { .standard(font) }
    }

    /// Resource name (`F1`, `F2`, …) for an embedded font, registering on first use.
    func resourceName(for font: EmbeddedFont) -> String {
        register(key: "emb:" + font.fontKey) { .embedded(font) }
    }

    private func register(key: String, _ make: () -> FontRef) -> String {
        if let existing = resourceNameByKey[key] { return existing }
        let name = "F\(fonts.count + 1)"
        fonts.append((name, make()))
        resourceNameByKey[key] = name
        return name
    }
}
