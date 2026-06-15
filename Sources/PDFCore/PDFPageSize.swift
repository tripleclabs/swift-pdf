// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// A page size in PDF points (1/72 inch). Width/height define the MediaBox.
public struct PDFPageSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// Swap width/height for landscape orientation.
    public var landscape: PDFPageSize { PDFPageSize(width: max(width, height), height: min(width, height)) }
    /// Swap width/height for portrait orientation.
    public var portrait: PDFPageSize { PDFPageSize(width: min(width, height), height: max(width, height)) }

    // ISO 216 A series (rounded to PDF points).
    public static let a3 = PDFPageSize(width: 841.89, height: 1190.55)
    public static let a4 = PDFPageSize(width: 595.28, height: 841.89)
    public static let a5 = PDFPageSize(width: 419.53, height: 595.28)
    // US sizes.
    public static let letter = PDFPageSize(width: 612, height: 792)
    public static let legal = PDFPageSize(width: 612, height: 1008)
    public static let tabloid = PDFPageSize(width: 792, height: 1224)
}
