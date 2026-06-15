// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
@testable import PDFCore

final class PDFDocumentTests: XCTestCase {

    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    func testEmptyMultiPageDocument() {
        let doc = PDFDocument()
        doc.addPage(size: .a4)
        doc.addPage(size: .letter)
        let s = text(doc.data())

        XCTAssertTrue(s.hasPrefix("%PDF-1.7\n"))
        // Two Page objects ("/Type /Page " — trailing space excludes "/Type /Pages ").
        XCTAssertEqual(s.components(separatedBy: "/Type /Page ").count - 1, 2)
        XCTAssertEqual(s.components(separatedBy: "/Type /Pages ").count - 1, 1)
        XCTAssertTrue(s.contains("/Count 2"))
        XCTAssertTrue(s.contains("/MediaBox [0 0 595.28 841.89]"))   // a4
        XCTAssertTrue(s.contains("/MediaBox [0 0 612 792]"))         // letter
        XCTAssertTrue(s.hasSuffix("%%EOF\n"))
    }

    func testPageCountAndKids() {
        let doc = PDFDocument()
        for _ in 0..<3 { doc.addPage() }
        XCTAssertEqual(doc.pages.count, 3)
        let s = text(doc.data())
        XCTAssertTrue(s.contains("/Count 3"))
        // Kids array references three page objects.
        XCTAssertNotNil(s.range(of: "/Kids \\[\\d+ 0 R \\d+ 0 R \\d+ 0 R\\]", options: .regularExpression))
    }

    func testLandscapeOrientation() {
        let doc = PDFDocument()
        doc.addPage(size: .a4.landscape)
        let s = text(doc.data())
        XCTAssertTrue(s.contains("/MediaBox [0 0 841.89 595.28]"))
    }

    func testMetadataOmittedWhenEmpty() {
        // Default metadata has producer="swift-pdf" -> an /Info is emitted with
        // exactly Producer, and the trailer references it.
        let doc = PDFDocument()
        doc.addPage()
        let s = text(doc.data())
        XCTAssertTrue(s.contains("/Producer (swift-pdf)"))
        XCTAssertTrue(s.contains("/Info"))
    }

    func testMetadataFields() {
        var meta = PDFMetadata()
        meta.title = "Report"
        meta.author = "Jane"
        meta.creationDate = Date(timeIntervalSince1970: 1_700_000_000) // fixed -> deterministic
        let doc = PDFDocument(metadata: meta)
        doc.addPage()
        let s = text(doc.data())
        XCTAssertTrue(s.contains("/Title (Report)"))
        XCTAssertTrue(s.contains("/Author (Jane)"))
        XCTAssertTrue(s.contains("/CreationDate (D:2023"), "date formatted as PDF date string")
    }

    func testDeterministicOutput() {
        func make() -> Data {
            var meta = PDFMetadata()
            meta.title = "X"
            meta.creationDate = Date(timeIntervalSince1970: 1_700_000_000)
            let d = PDFDocument(metadata: meta)
            d.addPage(size: .a4)
            return d.data()
        }
        XCTAssertEqual(make(), make())
    }

    func testNoProducerWhenCleared() {
        var meta = PDFMetadata()
        meta.producer = nil
        let doc = PDFDocument(metadata: meta)
        doc.addPage()
        let s = text(doc.data())
        XCTAssertFalse(s.contains("/Info"), "no Info dict when all metadata fields are empty")
    }
}
