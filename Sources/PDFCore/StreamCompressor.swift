// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// Compresses PDF stream payloads. Implemented outside PDFCore (e.g. a
/// zlib-backed `FlateCompressor`) so the core stays free of native
/// dependencies; a document with no compressor emits uncompressed streams.
public protocol StreamCompressor: Sendable {
    /// Compress `data`, returning the PDF `/Filter` name and compressed bytes,
    /// or `nil` to leave the stream uncompressed.
    func compress(_ data: [UInt8]) -> (filter: String, bytes: [UInt8])?
}
