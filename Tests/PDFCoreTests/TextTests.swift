// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
@testable import PDFCore

final class TextTests: XCTestCase {

    func testKnownHelveticaWidths() {
        // Adobe Helvetica metrics (1000-em): space=278, A=667, a=556, W=944.
        XCTAssertEqual(StandardFont.helvetica.advanceWidth(forCode: 0x20), 278)
        XCTAssertEqual(StandardFont.helvetica.advanceWidth(forCode: 0x41), 667)
        XCTAssertEqual(StandardFont.helvetica.advanceWidth(forCode: 0x61), 556)
        XCTAssertEqual(StandardFont.helvetica.advanceWidth(forCode: 0x57), 944)
    }

    func testCourierIsMonospaced() {
        // Every Courier glyph advances 600 units.
        for code in 0x20...0x7E {
            XCTAssertEqual(StandardFont.courier.advanceWidth(forCode: code), 600)
        }
    }

    func testTextWidthScalesWithSize() {
        let ctx = DrawingContext(page: PDFPage(size: .a4))
        // "AW" = 667 + 944 = 1611 units; at 12pt -> 1611 * 12 / 1000.
        XCTAssertEqual(ctx.textWidth("AW", font: .helvetica, size: 12), 1611.0 * 12 / 1000, accuracy: 1e-9)
        // At 24pt it doubles.
        XCTAssertEqual(ctx.textWidth("AW", font: .helvetica, size: 24),
                       ctx.textWidth("AW", font: .helvetica, size: 12) * 2, accuracy: 1e-9)
    }

    func testShowEmitsTextOperators() {
        let page = PDFPage(size: .letter)
        page.draw { ctx in
            ctx.setFont(.helvetica, size: 24)
            ctx.show("Hello, World", at: Point(x: 72, y: 720))
        }
        let s = String(decoding: page.content, as: UTF8.self)
        XCTAssertTrue(s.contains("BT\n"))
        XCTAssertTrue(s.contains("/F1 24 Tf"))
        XCTAssertTrue(s.contains("72 720 Td"))
        XCTAssertTrue(s.contains("(Hello, World) Tj"))
        XCTAssertTrue(s.contains("ET\n"))
    }

    func testFontResourcesEmittedAndDeduplicated() {
        let doc = PDFDocument()
        let page = doc.addPage(size: .a4)
        page.draw { ctx in
            ctx.setFont(.helvetica, size: 12)
            ctx.show("a", at: Point(x: 10, y: 10))
            ctx.setFont(.timesBold, size: 14)
            ctx.show("b", at: Point(x: 10, y: 30))
            ctx.setFont(.helvetica, size: 18)        // reuse -> same resource
            ctx.show("c", at: Point(x: 10, y: 50))
        }
        XCTAssertEqual(page.fonts.count, 2, "helvetica reused, times added -> 2 resources")
        let s = String(decoding: doc.data(), as: UTF8.self)
        XCTAssertTrue(s.contains("/BaseFont /Helvetica"))
        XCTAssertTrue(s.contains("/BaseFont /Times-Bold"))
        XCTAssertTrue(s.contains("/Encoding /WinAnsiEncoding"))
        XCTAssertTrue(s.contains("/Font <<"))
    }

    func testSymbolicFontHasNoWinAnsiEncoding() {
        let doc = PDFDocument()
        let page = doc.addPage()
        page.draw { ctx in
            ctx.setFont(.zapfDingbats, size: 12)
            ctx.show("a", at: .zero)
        }
        let s = String(decoding: doc.data(), as: UTF8.self)
        XCTAssertTrue(s.contains("/BaseFont /ZapfDingbats"))
        // Symbolic fonts omit /Encoding (use built-in font-specific encoding).
        let fontDictRange = s.range(of: "/BaseFont /ZapfDingbats")!
        let around = s[fontDictRange.lowerBound..<s.index(fontDictRange.upperBound, offsetBy: min(40, s.distance(from: fontDictRange.upperBound, to: s.endIndex)))]
        XCTAssertFalse(around.contains("WinAnsi"))
    }

    func testNonAsciiCharactersDropped() {
        // M4 limitation: only printable ASCII is encoded.
        let page = PDFPage(size: .a4)
        page.draw { ctx in
            ctx.setFont(.helvetica, size: 12)
            ctx.show("A\u{00E9}B", at: .zero)   // "AéB" -> "AB"
        }
        let s = String(decoding: page.content, as: UTF8.self)
        XCTAssertTrue(s.contains("(AB) Tj"))
    }
}
