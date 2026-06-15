// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
@testable import PDFFonts

/// The M6 risk gate: subsetting with RETAIN_GIDS must preserve glyph ids, so
/// that glyph ids already written into content streams stay valid after the
/// font is subset at document finalize. If this fails, embedded text renders
/// as the wrong glyphs.
final class HarfBuzzGateTests: XCTestCase {

    private func fixtureFont() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "ComingSoon-Regular", withExtension: "ttf", subdirectory: "Fixtures"),
            "missing test font fixture")
        return try Data(contentsOf: url)
    }

    func testHarfBuzzLinks() {
        XCTAssertFalse(HarfBuzz.version.isEmpty)
    }

    func testShapingProducesGlyphs() throws {
        let glyphs = HarfBuzz.shape(try fixtureFont(), text: "Hello, World")
        XCTAssertEqual(glyphs.count, 12, "one glyph per ASCII character")
        XCTAssertTrue(glyphs.allSatisfy { $0.gid != 0 }, "no .notdef glyphs for basic Latin")
        XCTAssertTrue(glyphs.allSatisfy { $0.advance > 0 }, "positive advances")
    }

    func testSubsetRetainsGlyphIDs() throws {
        let data = try fixtureFont()
        let text = "The quick brown fox jumps over the lazy dog 0123456789"
        let original = HarfBuzz.shape(data, text: text)
        XCTAssertFalse(original.isEmpty)

        let usedGIDs = Set(original.map(\.gid))
        let subset = try XCTUnwrap(HarfBuzz.subsetRetainingGIDs(data, gids: usedGIDs),
                                   "subset failed")

        // Re-shape the same text against the SUBSET font.
        let reshaped = HarfBuzz.shape(subset, text: text)

        // GIDs (and advances) must be byte-for-byte identical — this is the
        // whole point of RETAIN_GIDS.
        XCTAssertEqual(original, reshaped,
                       "RETAIN_GIDS subset must preserve glyph ids and advances")
        XCTAssertLessThan(subset.count, data.count, "subset should be smaller than the full font")
    }
}
