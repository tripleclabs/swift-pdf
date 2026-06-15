// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// Maps Unicode scalars to WinAnsiEncoding (cp1252) byte values, used to encode
/// text for the standard-14 fonts (which declare `/Encoding /WinAnsiEncoding`).
/// Covers all of Latin-1 (German, French, Spanish, …) plus the cp1252
/// punctuation block (€, smart quotes, dashes, …). Scalars with no WinAnsi
/// representation are dropped.
enum WinAnsi {
    /// The WinAnsi byte for a Unicode scalar, or nil if unrepresentable.
    static func byte(for scalar: UInt32) -> UInt8? {
        switch scalar {
        case 0x20...0x7E, 0xA0...0xFF:
            return UInt8(scalar)                 // ASCII + Latin-1 are identity
        default:
            return special[scalar]               // cp1252 0x80..0x9F block
        }
    }

    /// Encode a string into WinAnsi bytes, dropping unrepresentable scalars.
    static func encode(_ text: String) -> [UInt8] {
        text.unicodeScalars.compactMap { byte(for: $0.value) }
    }

    private static let special: [UInt32: UInt8] = [
        0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85,
        0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A,
        0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92,
        0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
        0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C,
        0x017E: 0x9E, 0x0178: 0x9F,
    ]
}
