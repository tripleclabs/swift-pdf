// Copyright (c) 2026 the swift-pdf authors.
// SPDX-License-Identifier: MIT

import XCTest
@testable import PDFCore

final class PDFObjectTests: XCTestCase {

    private func serialized(_ o: PDFObject) -> String {
        String(decoding: o.serializedBytes, as: UTF8.self)
    }

    func testScalars() {
        XCTAssertEqual(serialized(.null), "null")
        XCTAssertEqual(serialized(.boolean(true)), "true")
        XCTAssertEqual(serialized(.boolean(false)), "false")
        XCTAssertEqual(serialized(.integer(42)), "42")
        XCTAssertEqual(serialized(.integer(-7)), "-7")
    }

    func testRealFormattingIsCompactAndLocaleIndependent() {
        XCTAssertEqual(serialized(.real(1.0)), "1")           // whole -> integer form
        XCTAssertEqual(serialized(.real(0.5)), "0.5")
        XCTAssertEqual(serialized(.real(-0.25)), "-0.25")
        XCTAssertEqual(serialized(.real(12.340)), "12.34")    // trailing zeros trimmed
        XCTAssertEqual(serialized(.real(100.0)), "100")
        // No scientific notation, no locale comma.
        XCTAssertFalse(serialized(.real(0.0001)).contains("e"))
        XCTAssertFalse(serialized(.real(1.5)).contains(","))
    }

    func testNameEscaping() {
        XCTAssertEqual(serialized(.name("Helvetica")), "/Helvetica")
        XCTAssertEqual(serialized(.name("A B")), "/A#20B")       // space -> #20
        XCTAssertEqual(serialized(.name("a/b")), "/a#2Fb")       // slash -> #2F
    }

    func testLiteralStringEscaping() {
        XCTAssertEqual(serialized(.string("Hello, World")), "(Hello, World)")
        XCTAssertEqual(serialized(.string("a(b)c")), "(a\\(b\\)c)")
        XCTAssertEqual(serialized(.string("back\\slash")), "(back\\\\slash)")
    }

    func testHexString() {
        XCTAssertEqual(serialized(.hexString([0x00, 0xFF, 0x10])), "<00FF10>")
    }

    func testArrayAndDictionaryOrdering() {
        XCTAssertEqual(serialized(.array([.integer(0), .integer(0), .integer(612), .integer(792)])),
                       "[0 0 612 792]")
        let d = PDFObject.dict([("Type", .name("Page")), ("Count", .integer(1))])
        XCTAssertEqual(serialized(d), "<< /Type /Page /Count 1 >>")
    }

    func testStreamCarriesLength() {
        let s = PDFObject.streamObject([("Filter", .name("FlateDecode"))], Array("abc".utf8))
        let text = serialized(s)
        XCTAssertTrue(text.contains("/Length 3"))
        XCTAssertTrue(text.contains("stream\nabc\nendstream"))
    }
}
