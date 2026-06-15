// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import CHarfBuzz
import Foundation

/// A loaded font with persistent HarfBuzz handles, reused across shaping,
/// metric, and subsetting calls. Owns a duplicated copy of the font bytes.
final class HBFont {
    let data: Data
    private let blob: OpaquePointer
    private let face: OpaquePointer
    private let font: OpaquePointer
    let unitsPerEm: Int

    init?(data: Data, faceIndex: UInt32) {
        guard let blob = data.withUnsafeBytes({ raw in
            hb_blob_create(raw.baseAddress?.assumingMemoryBound(to: CChar.self),
                           UInt32(data.count), HB_MEMORY_MODE_DUPLICATE, nil, nil)
        }) else { return nil }
        self.blob = blob
        self.face = hb_face_create(blob, faceIndex)
        self.font = hb_font_create(face)
        self.data = data
        let upem = hb_face_get_upem(face)
        self.unitsPerEm = upem > 0 ? Int(upem) : 1000
    }

    deinit {
        hb_font_destroy(font)
        hb_face_destroy(face)
        hb_blob_destroy(blob)
    }

    /// Shape `text` (LTR, auto-detected script), returning glyphs.
    func shape(_ text: String) -> [HarfBuzz.ShapedGlyph] {
        let buffer = hb_buffer_create()
        defer { hb_buffer_destroy(buffer) }
        let utf8 = Array(text.utf8)
        utf8.withUnsafeBufferPointer { p in
            p.baseAddress?.withMemoryRebound(to: CChar.self, capacity: p.count) { cstr in
                hb_buffer_add_utf8(buffer, cstr, Int32(p.count), 0, Int32(p.count))
            }
        }
        hb_buffer_guess_segment_properties(buffer)
        hb_shape(font, buffer, nil, 0)

        var count: UInt32 = 0
        let infos = hb_buffer_get_glyph_infos(buffer, &count)
        let positions = hb_buffer_get_glyph_positions(buffer, &count)
        var glyphs: [HarfBuzz.ShapedGlyph] = []
        glyphs.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            glyphs.append(.init(gid: infos![i].codepoint,
                                advance: positions![i].x_advance,
                                cluster: infos![i].cluster))
        }
        return glyphs
    }

    /// Horizontal advance of a glyph in font units.
    func advance(gid: UInt32) -> Int32 { hb_font_get_glyph_h_advance(font, gid) }

    /// Horizontal font extents (font units): ascender (+), descender (−).
    var extents: (ascender: Int, descender: Int) {
        var e = hb_font_extents_t()
        hb_font_get_h_extents(font, &e)
        return (Int(e.ascender), Int(e.descender))
    }

    /// The PostScript name from the font's `name` table, if present.
    func postScriptName() -> String? {
        var length: UInt32 = 127
        var buf = [CChar](repeating: 0, count: 128)
        let n = hb_ot_name_get_utf8(face, hb_ot_name_id_t(6 /* POSTSCRIPT_NAME */),
                                    nil, &length, &buf)
        guard n > 0 else { return nil }
        return String(cString: buf)
    }

    /// Global glyph bounding box from the `head` table (font units), if present.
    func headBoundingBox() -> (xMin: Int, yMin: Int, xMax: Int, yMax: Int)? {
        let tag: UInt32 = (UInt32(UInt8(ascii: "h")) << 24) | (UInt32(UInt8(ascii: "e")) << 16)
                        | (UInt32(UInt8(ascii: "a")) << 8) | UInt32(UInt8(ascii: "d"))
        let table = hb_face_reference_table(face, tag)
        defer { hb_blob_destroy(table) }
        var len: UInt32 = 0
        guard let ptr = hb_blob_get_data(table, &len), len >= 44 else { return nil }
        let bytes = UnsafeRawBufferPointer(start: ptr, count: Int(len))
        func i16(_ offset: Int) -> Int {
            let hi = Int(bytes[offset]), lo = Int(bytes[offset + 1])
            let v = (hi << 8) | lo
            return v >= 0x8000 ? v - 0x10000 : v
        }
        return (i16(36), i16(38), i16(40), i16(42))
    }

    /// Subset to `gids`, retaining original glyph ids (see the M6 gate).
    func subset(gids: Set<UInt32>) -> Data? {
        guard let input = hb_subset_input_create_or_fail() else { return nil }
        defer { hb_subset_input_destroy(input) }
        let glyphSet = hb_subset_input_glyph_set(input)
        for gid in gids { hb_set_add(glyphSet, gid) }
        hb_subset_input_set_flags(input, HB_SUBSET_FLAGS_RETAIN_GIDS.rawValue)

        guard let subsetFace = hb_subset_or_fail(face, input) else { return nil }
        defer { hb_face_destroy(subsetFace) }
        let subsetBlob = hb_face_reference_blob(subsetFace)
        defer { hb_blob_destroy(subsetBlob) }
        var length: UInt32 = 0
        guard let ptr = hb_blob_get_data(subsetBlob, &length), length > 0 else { return nil }
        return Data(bytes: ptr, count: Int(length))
    }
}
