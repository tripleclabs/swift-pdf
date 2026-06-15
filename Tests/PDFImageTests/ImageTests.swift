// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
import PDFCore
@testable import PDFImage

final class ImageTests: XCTestCase {

    private func fixturePNG() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "quadrants", withExtension: "png", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testDecodePNGProducesRGBPlusSoftMask() throws {
        let image = try PDFImageLoader.png(fixturePNG())
        XCTAssertEqual(image.width, 8)
        XCTAssertEqual(image.height, 8)
        XCTAssertEqual(image.bitsPerComponent, 8)
        XCTAssertEqual(image.colorSpace, .deviceRGB)
        XCTAssertEqual(image.data.count, 8 * 8 * 3, "RGB samples")
        XCTAssertEqual(image.filter, nil, "raw samples (no pre-applied filter)")
        // The bottom-right quadrant is 50% alpha -> a soft mask is produced.
        let mask = try XCTUnwrap(image.softMask)
        XCTAssertEqual(mask.data.count, 8 * 8)
        XCTAssertTrue(mask.data.contains(128), "the translucent quadrant is in the mask")
        // First pixel (top-left) is opaque red.
        XCTAssertEqual(Array(image.data.prefix(3)), [220, 40, 40])
    }

    func testEmbeddedPNGProducesImageXObjectAndSMask() throws {
        let image = try PDFImageLoader.png(fixturePNG())
        let doc = PDFDocument()
        let page = doc.addPage(size: .letter)
        page.draw { ctx in
            ctx.draw(image, in: Rectangle(x: 100, y: 500, width: 200, height: 200))
        }
        let s = String(decoding: doc.data(), as: UTF8.self)
        XCTAssertTrue(s.contains("/Subtype /Image"))
        XCTAssertTrue(s.contains("/ColorSpace /DeviceRGB"))
        XCTAssertTrue(s.contains("/SMask"))                 // alpha channel
        XCTAssertTrue(s.contains("/XObject <<"))
        XCTAssertTrue(s.contains("/Im1 Do"))
        XCTAssertTrue(s.contains("200 0 0 200 100 500 cm"), "image placement matrix")
    }

    func testImageDeduplicatedAcrossPages() throws {
        let image = try PDFImageLoader.png(fixturePNG())
        let doc = PDFDocument()
        for _ in 0..<3 {
            let page = doc.addPage()
            page.draw { $0.draw(image, in: Rectangle(x: 0, y: 0, width: 50, height: 50)) }
        }
        let s = String(decoding: doc.data(), as: UTF8.self)
        // One image XObject + one SMask, shared by all three pages.
        XCTAssertEqual(s.components(separatedBy: "/Subtype /Image").count - 1, 2)
    }

    func testJPEGSOFParsing() throws {
        // Minimal synthetic JPEG: SOI + SOF0 (precision 8, 64x80, 3 components) + EOI.
        let jpeg = Data([
            0xFF, 0xD8,                         // SOI
            0xFF, 0xC0, 0x00, 0x11, 0x08,       // SOF0, length, precision
            0x00, 0x40,                         // height = 64
            0x00, 0x50,                         // width = 80
            0x03,                               // components = 3
            0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
            0xFF, 0xD9,                         // EOI
        ])
        let image = try PDFImageLoader.jpeg(jpeg)
        XCTAssertEqual(image.width, 80)
        XCTAssertEqual(image.height, 64)
        XCTAssertEqual(image.colorSpace, .deviceRGB)
        XCTAssertEqual(image.filter, "DCTDecode")
        XCTAssertEqual(image.data.count, jpeg.count, "JPEG embedded as-is (passthrough)")
    }

    /// Write a sample with an embedded image to /tmp for visual verification.
    func testWriteImageSample() throws {
        let image = try PDFImageLoader.png(fixturePNG())
        let doc = PDFDocument()
        let page = doc.addPage(size: .letter)
        page.draw { ctx in
            // Draw the 8x8 image scaled up (nearest-neighbour by the viewer).
            ctx.draw(image, in: Rectangle(x: 80, y: 480, width: 240, height: 240))
        }
        try doc.data().write(to: URL(fileURLWithPath: "/tmp/swiftpdf-m7.pdf"))
    }
}
