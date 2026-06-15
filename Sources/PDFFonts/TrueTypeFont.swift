// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import Foundation
import PDFCore

public enum FontError: Error { case couldNotLoad }

/// A TrueType/OpenType font loaded for embedding. Shapes text via HarfBuzz,
/// accumulates the glyphs actually used, and at document finalize subsets the
/// font and emits a Type0/CIDFontType2 structure with `/W` widths and a
/// `/ToUnicode` map (so the text stays extractable/searchable).
public final class TrueTypeFont: EmbeddedFont {
    private let hb: HBFont
    public let fontKey: String
    public var usesHexString: Bool { true }   // Identity-H: 2-byte glyph ids

    private var usedGIDs: Set<UInt32> = []
    private var gidToScalar: [UInt32: UInt32] = [:]
    private let subsetTag: String

    public init(data: Data, faceIndex: Int = 0) throws {
        guard let hb = HBFont(data: data, faceIndex: UInt32(faceIndex)) else {
            throw FontError.couldNotLoad
        }
        self.hb = hb
        let h = Self.fnv1a(data)
        self.fontKey = "ttf:\(h)"
        self.subsetTag = Self.tag(from: h)
    }

    private var baseFontName: String {
        subsetTag + "+" + (hb.postScriptName() ?? "Font")
    }

    // 1000-unit em scaling from the font's own units.
    private func toEm(_ v: Int) -> Int { Int((Double(v) * 1000.0 / Double(hb.unitsPerEm)).rounded()) }

    public func width(of text: String, size: Double) -> Double {
        let advance = hb.shape(text).reduce(0) { $0 + Int($1.advance) }
        return Double(advance) * size / Double(hb.unitsPerEm)
    }

    public func ascent(forSize size: Double) -> Double {
        Double(hb.extents.ascender) * size / Double(hb.unitsPerEm)
    }

    public func encode(_ text: String, size: Double) -> (operand: [UInt8], width: Double) {
        let scalarsByOffset = Self.scalarsByUTF8Offset(text)
        var operand: [UInt8] = []
        var advance = 0
        for g in hb.shape(text) {
            usedGIDs.insert(g.gid)
            operand.append(UInt8(g.gid >> 8))
            operand.append(UInt8(g.gid & 0xFF))
            advance += Int(g.advance)
            if gidToScalar[g.gid] == nil, let s = scalarsByOffset[Int(g.cluster)] {
                gidToScalar[g.gid] = s
            }
        }
        return (operand, Double(advance) * size / Double(hb.unitsPerEm))
    }

    public func buildFontObject(into writer: PDFWriter) -> Int {
        let subsetData = hb.subset(gids: usedGIDs) ?? hb.data
        let name = baseFontName

        // Embedded subset program.
        let fontFile = writer.add(.streamObject(
            [("Length1", .integer(subsetData.count))], [UInt8](subsetData)))

        let (asc, desc) = hb.extents
        let bbox: [Int]
        if let b = hb.headBoundingBox() {
            bbox = [toEm(b.xMin), toEm(b.yMin), toEm(b.xMax), toEm(b.yMax)]
        } else {
            bbox = [0, toEm(desc), 1000, toEm(asc)]
        }

        let descriptor = writer.add(.dict([
            ("Type", .name("FontDescriptor")),
            ("FontName", .name(name)),
            ("Flags", .integer(4)),                     // Symbolic
            ("FontBBox", .array(bbox.map { .integer($0) })),
            ("ItalicAngle", .integer(0)),
            ("Ascent", .integer(toEm(asc))),
            ("Descent", .integer(toEm(desc))),
            ("CapHeight", .integer(toEm(asc))),
            ("StemV", .integer(80)),                    // approximation
            ("FontFile2", .reference(fontFile)),
        ]))

        // Per-glyph widths in glyph space (1000-em).
        var w: [PDFObject] = []
        for gid in usedGIDs.sorted() {
            w.append(.integer(Int(gid)))
            w.append(.array([.integer(toEm(Int(hb.advance(gid: gid))))]))
        }

        let cidFont = writer.add(.dict([
            ("Type", .name("Font")),
            ("Subtype", .name("CIDFontType2")),
            ("BaseFont", .name(name)),
            ("CIDSystemInfo", .dict([
                ("Registry", .string("Adobe")),
                ("Ordering", .string("Identity")),
                ("Supplement", .integer(0)),
            ])),
            ("FontDescriptor", .reference(descriptor)),
            ("CIDToGIDMap", .name("Identity")),
            ("DW", .integer(toEm(Int(hb.advance(gid: 0))))),
            ("W", .array(w)),
        ]))

        let toUnicode = writer.add(.streamObject([], buildToUnicodeCMap()))

        return writer.add(.dict([
            ("Type", .name("Font")),
            ("Subtype", .name("Type0")),
            ("BaseFont", .name(name)),
            ("Encoding", .name("Identity-H")),
            ("DescendantFonts", .array([.reference(cidFont)])),
            ("ToUnicode", .reference(toUnicode)),
        ]))
    }

    // MARK: - ToUnicode

    private func buildToUnicodeCMap() -> [UInt8] {
        let entries = gidToScalar.sorted { $0.key < $1.key }
        var s = """
        /CIDInit /ProcSet findresource begin
        12 dict begin
        begincmap
        /CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
        /CMapName /Adobe-Identity-UCS def
        /CMapType 2 def
        1 begincodespacerange
        <0000> <FFFF>
        endcodespacerange

        """
        for chunk in stride(from: 0, to: entries.count, by: 100) {
            let slice = entries[chunk..<min(chunk + 100, entries.count)]
            s += "\(slice.count) beginbfchar\n"
            for (gid, scalar) in slice {
                s += "<\(Self.hex4(UInt16(gid & 0xFFFF)))> <\(Self.utf16BEHex(scalar))>\n"
            }
            s += "endbfchar\n"
        }
        s += """
        endcmap
        CMapName currentdict /CMap defineresource pop
        end
        end
        """
        return Array(s.utf8)
    }

    // MARK: - Helpers

    private static func scalarsByUTF8Offset(_ text: String) -> [Int: UInt32] {
        var map: [Int: UInt32] = [:]
        var offset = 0
        for scalar in text.unicodeScalars {
            map[offset] = scalar.value
            offset += String(scalar).utf8.count
        }
        return map
    }

    private static func hex4(_ v: UInt16) -> String {
        let h = String(v, radix: 16, uppercase: true)
        return String(repeating: "0", count: 4 - h.count) + h
    }

    /// UTF-16 big-endian hex of a scalar (surrogate pair if outside the BMP).
    private static func utf16BEHex(_ scalar: UInt32) -> String {
        if scalar <= 0xFFFF { return hex4(UInt16(scalar)) }
        let v = scalar - 0x10000
        let hi = UInt16(0xD800 + (v >> 10)), lo = UInt16(0xDC00 + (v & 0x3FF))
        return hex4(hi) + hex4(lo)
    }

    private static func fnv1a(_ data: Data) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return hash
    }

    /// Six uppercase letters derived from `hash`, for the subset `/BaseFont` tag.
    private static func tag(from hash: UInt64) -> String {
        var h = hash
        var letters = ""
        for _ in 0..<6 {
            letters += String(UnicodeScalar(UInt8(65 + Int(h % 26))))
            h /= 26
        }
        return letters
    }
}
