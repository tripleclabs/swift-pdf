// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

// Public umbrella for swift-pdf. Re-exports the pure-Swift core plus the
// optional capability layers so consumers `import SwiftPDF` and get everything.
@_exported import PDFCore
@_exported import PDFFlate

extension PDFDocument {
    /// Enable FlateDecode compression of stream payloads (links zlib).
    public func useFlateCompression(level: Int32 = 6) {
        compressor = FlateCompressor(level: level)
    }
}
