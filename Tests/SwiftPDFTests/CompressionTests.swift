// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import CZlib
@testable import SwiftPDF

final class CompressionTests: XCTestCase {

    /// Inflate a zlib stream back to `expectedSize` bytes (test-side check).
    private func inflate(_ data: [UInt8], expectedSize: Int) -> [UInt8] {
        var destLen = uLong(expectedSize)
        var dest = [UInt8](repeating: 0, count: expectedSize)
        let status = data.withUnsafeBufferPointer { src in
            dest.withUnsafeMutableBufferPointer { dst in
                uncompress(dst.baseAddress, &destLen, src.baseAddress, uLong(data.count))
            }
        }
        precondition(status == Z_OK, "uncompress failed: \(status)")
        dest.removeLast(dest.count - Int(destLen))
        return dest
    }

    func testFlateRoundTrips() {
        let original = Array(String(repeating: "Hello, World! ", count: 200).utf8)
        guard let (filter, compressed) = FlateCompressor().compress(original) else {
            return XCTFail("compress returned nil")
        }
        XCTAssertEqual(filter, "FlateDecode")
        XCTAssertLessThan(compressed.count, original.count, "compressible data should shrink")
        XCTAssertEqual(inflate(compressed, expectedSize: original.count), original)
    }

    func testEmptyInputReturnsNil() {
        XCTAssertNil(FlateCompressor().compress([]))
    }

    func testDocumentCompressionShrinksAndStaysValid() {
        func make(compress: Bool) -> Data {
            let doc = PDFDocument()
            if compress { doc.useFlateCompression() }
            let page = doc.addPage()
            page.draw { ctx in
                ctx.setFont(.helvetica, size: 11)
                for i in 0..<60 {
                    ctx.show("Line \(i): the quick brown fox jumps over the lazy dog",
                             at: Point(x: 50, y: 760 - Double(i) * 11))
                }
            }
            return doc.data()
        }
        let plain = make(compress: false)
        let compressed = make(compress: true)
        XCTAssertLessThan(compressed.count, plain.count, "compressed document should be smaller")
        XCTAssertTrue(String(decoding: compressed, as: UTF8.self).contains("/FlateDecode"))
    }

    func testIncompressibleStreamStaysUncompressed() {
        // A tiny page: Flate overhead would exceed any saving, so makeStream
        // keeps it raw (no /FlateDecode forced when it doesn't help).
        let doc = PDFDocument()
        doc.useFlateCompression()
        doc.addPage()   // empty content stream
        let s = String(decoding: doc.data(), as: UTF8.self)
        XCTAssertFalse(s.contains("/FlateDecode"), "trivial stream should not be force-compressed")
    }
}
