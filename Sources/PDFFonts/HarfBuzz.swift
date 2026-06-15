// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import CHarfBuzz
import Foundation

/// Thin wrappers over the HarfBuzz C API used for font shaping and subsetting.
/// All blobs are created with DUPLICATE mode so HarfBuzz owns a copy and the
/// Swift source bytes need not outlive the call.
enum HarfBuzz {

    /// A shaped glyph: its glyph id (GID) and advance in font units.
    struct ShapedGlyph: Equatable {
        var gid: UInt32
        var advance: Int32
        var cluster: UInt32
    }

    private static func makeBlob(_ data: Data) -> OpaquePointer? {
        data.withUnsafeBytes { raw in
            hb_blob_create(
                raw.baseAddress?.assumingMemoryBound(to: CChar.self),
                UInt32(data.count),
                HB_MEMORY_MODE_DUPLICATE,
                nil, nil
            )
        }
    }

    /// Shape `text` with the font in `data` (face `index`), returning the glyphs.
    static func shape(_ data: Data, faceIndex: UInt32 = 0, text: String) -> [ShapedGlyph] {
        guard let blob = makeBlob(data) else { return [] }
        defer { hb_blob_destroy(blob) }
        let face = hb_face_create(blob, faceIndex)
        defer { hb_face_destroy(face) }
        let font = hb_font_create(face)
        defer { hb_font_destroy(font) }

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
        var glyphs: [ShapedGlyph] = []
        glyphs.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            glyphs.append(ShapedGlyph(
                gid: infos![i].codepoint,
                advance: positions![i].x_advance,
                cluster: infos![i].cluster
            ))
        }
        return glyphs
    }

    /// Subset the font in `data` to `gids`, retaining the original glyph ids
    /// (so glyph ids already written into content streams stay valid).
    static func subsetRetainingGIDs(_ data: Data, faceIndex: UInt32 = 0, gids: Set<UInt32>) -> Data? {
        guard let blob = makeBlob(data) else { return nil }
        defer { hb_blob_destroy(blob) }
        let face = hb_face_create(blob, faceIndex)
        defer { hb_face_destroy(face) }

        guard let input = hb_subset_input_create_or_fail() else { return nil }
        defer { hb_subset_input_destroy(input) }
        let glyphSet = hb_subset_input_glyph_set(input)
        for gid in gids { hb_set_add(glyphSet, gid) }
        // Keep original GIDs; preserve cmap/name so the result is a usable font.
        hb_subset_input_set_flags(input, HB_SUBSET_FLAGS_RETAIN_GIDS.rawValue)

        guard let subsetFace = hb_subset_or_fail(face, input) else { return nil }
        defer { hb_face_destroy(subsetFace) }
        let subsetBlob = hb_face_reference_blob(subsetFace)
        defer { hb_blob_destroy(subsetBlob) }

        var length: UInt32 = 0
        guard let ptr = hb_blob_get_data(subsetBlob, &length), length > 0 else { return nil }
        return Data(bytes: ptr, count: Int(length))
    }

    /// HarfBuzz version string (linkage smoke check).
    static var version: String { String(cString: hb_version_string()) }
}
