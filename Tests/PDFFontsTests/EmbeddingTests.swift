// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
import PDFCore
@testable import PDFFonts

final class EmbeddingTests: XCTestCase {

    private func fixtureFont() throws -> TrueTypeFont {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "ComingSoon-Regular", withExtension: "ttf", subdirectory: "Fixtures"))
        return try TrueTypeFont(data: Data(contentsOf: url))
    }

    func testEmbeddedFontProducesType0Structure() throws {
        let font = try fixtureFont()
        let doc = PDFDocument()
        let page = doc.addPage(size: .letter)
        page.draw { ctx in
            ctx.setFont(font, size: 28)
            ctx.show("Hello, World", at: Point(x: 72, y: 700))
        }
        let s = String(decoding: doc.data(), as: UTF8.self)

        // The Type0 / CIDFontType2 embedding structure.
        XCTAssertTrue(s.contains("/Subtype /Type0"))
        XCTAssertTrue(s.contains("/Encoding /Identity-H"))
        XCTAssertTrue(s.contains("/Subtype /CIDFontType2"))
        XCTAssertTrue(s.contains("/CIDToGIDMap /Identity"))
        XCTAssertTrue(s.contains("/FontFile2"))
        XCTAssertTrue(s.contains("/ToUnicode"))
        XCTAssertTrue(s.contains("/W ["))
        // Subset tag: 6 uppercase letters + '+' before the PostScript name.
        XCTAssertNotNil(s.range(of: "/BaseFont /[A-Z]{6}\\+", options: .regularExpression))
        // Glyph ids are emitted as a hex string, not literal text.
        XCTAssertNotNil(s.range(of: "<[0-9A-F]+> Tj", options: .regularExpression))
    }

    func testWidthMeasurementIsPositiveAndScales() throws {
        let font = try fixtureFont()
        let w12 = font.width(of: "Hello", size: 12)
        let w24 = font.width(of: "Hello", size: 24)
        XCTAssertGreaterThan(w12, 0)
        XCTAssertEqual(w24, w12 * 2, accuracy: 1e-9)
    }

    func testEmbeddedFontIsSubsetAndDeduplicated() throws {
        let font = try fixtureFont()
        let doc = PDFDocument()
        // Use the same font instance across two pages -> embedded once.
        for _ in 0..<2 {
            let page = doc.addPage()
            page.draw { ctx in
                ctx.setFont(font, size: 18)
                ctx.show("abc", at: Point(x: 50, y: 50))
            }
        }
        let s = String(decoding: doc.data(), as: UTF8.self)
        XCTAssertEqual(s.components(separatedBy: "/FontFile2").count - 1, 1,
                       "font embedded exactly once across pages")
    }

    /// Write a sample to /tmp for external PDFKit/visual verification.
    func testWriteEmbeddedSample() throws {
        let font = try fixtureFont()
        let doc = PDFDocument()
        let page = doc.addPage(size: .letter)
        page.draw { ctx in
            ctx.setFillColor(.rgb(red: 0.1, green: 0.2, blue: 0.6))
            ctx.setFont(font, size: 30)
            ctx.show("Embedded TTF via HarfBuzz", at: Point(x: 60, y: 700))
            ctx.setFillColor(.black)
            ctx.setFont(font, size: 14)
            ctx.show("The quick brown fox jumps over the lazy dog 0123456789",
                     at: Point(x: 60, y: 660))
        }
        try doc.data().write(to: URL(fileURLWithPath: "/tmp/swiftpdf-m6.pdf"))
    }
}
