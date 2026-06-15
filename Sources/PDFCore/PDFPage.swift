// Copyright (c) 2026 the swift-pdf authors.
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

    init(size: PDFPageSize) {
        self.size = size
    }
}
