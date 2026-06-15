// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
@testable import PDFCore

final class PDFWriterTests: XCTestCase {

    /// Assemble a minimal single-page Helvetica document directly through the
    /// writer (the M2 document API will wrap this). Mutual references between
    /// the Pages node and the Page exercise reserve()/set().
    private func helloWorld(text: String = "Hello, World") -> Data {
        let w = PDFWriter()
        let catalog = w.reserve()
        let pages = w.reserve()

        let content = Array("BT\n/F1 24 Tf\n72 720 Td\n(\(text)) Tj\nET\n".utf8)
        let contentObj = w.add(.streamObject([], content))
        let fontObj = w.add(.dict([
            ("Type", .name("Font")),
            ("Subtype", .name("Type1")),
            ("BaseFont", .name("Helvetica")),
        ]))
        let page = w.add(.dict([
            ("Type", .name("Page")),
            ("Parent", .reference(pages)),
            ("MediaBox", .array([.integer(0), .integer(0), .integer(612), .integer(792)])),
            ("Resources", .dict([("Font", .dict([("F1", .reference(fontObj))]))])),
            ("Contents", .reference(contentObj)),
        ]))
        w.set(pages, .dict([
            ("Type", .name("Pages")),
            ("Kids", .array([.reference(page)])),
            ("Count", .integer(1)),
        ]))
        w.set(catalog, .dict([("Type", .name("Catalog")), ("Pages", .reference(pages))]))
        return w.build(rootRef: catalog)
    }

    func testHeaderAndTrailer() {
        let bytes = [UInt8](helloWorld())
        let text = String(decoding: bytes, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("%PDF-1.7\n"))
        XCTAssertTrue(text.contains("/Root 1 0 R"))
        XCTAssertTrue(text.hasSuffix("%%EOF\n"))
    }

    /// The structural invariant the spike validated: every in-use xref offset
    /// must land exactly on the start of an `N 0 obj` header.
    func testXrefOffsetsLandOnObjectHeaders() throws {
        let data = helloWorld()
        let bytes = [UInt8](data)
        let text = String(decoding: bytes, as: UTF8.self)

        // Find startxref offset.
        guard let r = text.range(of: "startxref\n") else { return XCTFail("no startxref") }
        let after = text[r.upperBound...]
        let offsetStr = after.prefix { $0.isNumber }
        guard let xrefOffset = Int(offsetStr) else { return XCTFail("bad startxref offset") }
        XCTAssertEqual(Array(bytes[xrefOffset..<xrefOffset + 4]), Array("xref".utf8))

        // Parse the 10-digit in-use entries and confirm each points at "N 0 obj".
        let entryRegex = try NSRegularExpression(pattern: "(\\d{10}) 00000 n")
        let ns = text as NSString
        let matches = entryRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        XCTAssertEqual(matches.count, 5, "expected 5 in-use objects")
        var checked = 0
        for m in matches {
            let off = Int(ns.substring(with: m.range(at: 1)))!
            let slice = String(decoding: bytes[off..<min(off + 12, bytes.count)], as: UTF8.self)
            XCTAssertTrue(slice.range(of: "^\\d+ 0 obj", options: .regularExpression) != nil,
                          "xref offset \(off) does not land on an object header: \(slice.debugDescription)")
            checked += 1
        }
        XCTAssertEqual(checked, 5)
    }

    func testDeterministicOutput() {
        // Same logical document twice -> byte-identical (self-regression basis).
        XCTAssertEqual(helloWorld(), helloWorld())
    }

    func testReservedButUnsetWouldTrap() {
        // Sanity: a fully-wired document does not trap and produces bytes.
        XCTAssertFalse(helloWorld().isEmpty)
    }
}
