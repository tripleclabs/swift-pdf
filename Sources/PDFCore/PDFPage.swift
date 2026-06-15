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

    /// Fonts referenced by this page, in resource order (`F1`, `F2`, …).
    private(set) var fonts: [(name: String, font: StandardFont)] = []
    private var resourceNameByBaseFont: [String: String] = [:]

    init(size: PDFPageSize) {
        self.size = size
    }

    /// Resource name (`F1`, `F2`, …) for `font`, registering it on first use
    /// and reusing the same name for repeated references.
    func resourceName(for font: StandardFont) -> String {
        if let existing = resourceNameByBaseFont[font.baseName] { return existing }
        let name = "F\(fonts.count + 1)"
        fonts.append((name, font))
        resourceNameByBaseFont[font.baseName] = name
        return name
    }
}
