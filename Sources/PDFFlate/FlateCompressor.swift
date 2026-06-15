// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import CZlib
import PDFCore

/// A `StreamCompressor` backed by zlib's `deflate` (RFC 1950 zlib format, which
/// is exactly what the PDF `FlateDecode` filter expects).
public struct FlateCompressor: StreamCompressor {
    /// zlib compression level, 0–9 (default 6).
    public let level: Int32

    public init(level: Int32 = 6) {
        self.level = level
    }

    public func compress(_ data: [UInt8]) -> (filter: String, bytes: [UInt8])? {
        guard !data.isEmpty else { return nil }
        var destLen = compressBound(uLong(data.count))
        var dest = [UInt8](repeating: 0, count: Int(destLen))
        let status = data.withUnsafeBufferPointer { src in
            dest.withUnsafeMutableBufferPointer { dst in
                compress2(dst.baseAddress, &destLen, src.baseAddress, uLong(data.count), level)
            }
        }
        guard status == Z_OK else { return nil }
        dest.removeLast(dest.count - Int(destLen))
        return ("FlateDecode", dest)
    }
}
