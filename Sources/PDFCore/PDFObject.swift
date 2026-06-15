// Copyright (c) 2026 the swift-pdf authors.
// SPDX-License-Identifier: MIT
//
// Original work implementing the COS object model of ISO 32000-1 (§7.3).
// Not derived from libharu.

/// A PDF COS object (ISO 32000-1, §7.3) — the substrate every higher-level
/// feature ultimately serializes down to.
///
/// Dictionaries preserve insertion order (an array of key/value pairs rather
/// than a `Dictionary`) so serialization is deterministic, which is what makes
/// Swift-vs-Swift byte snapshots a meaningful regression check.
public indirect enum PDFObject: Equatable, Sendable {
    case null
    case boolean(Bool)
    case integer(Int)
    case real(Double)
    case name(String)
    case string(String)                          // literal string: (...)
    case hexString([UInt8])                      // hexadecimal string: <...>
    case array([PDFObject])
    case dictionary([(key: String, value: PDFObject)])
    case reference(Int)                          // indirect reference "N 0 R"
    case stream(dict: [(key: String, value: PDFObject)], data: [UInt8])

    /// Append this object's PDF serialization to `out`.
    public func serialize(into out: inout [UInt8]) {
        switch self {
        case .null:
            out.append(contentsOf: Self.asciiBytes("null"))
        case .boolean(let b):
            out.append(contentsOf: Self.asciiBytes(b ? "true" : "false"))
        case .integer(let i):
            out.append(contentsOf: Self.asciiBytes(String(i)))
        case .real(let r):
            out.append(contentsOf: Self.asciiBytes(Self.formatReal(r)))
        case .name(let n):
            out.append(UInt8(ascii: "/"))
            out.append(contentsOf: Self.escapeName(n))
        case .string(let s):
            out.append(UInt8(ascii: "("))
            out.append(contentsOf: Self.escapeLiteralString(s))
            out.append(UInt8(ascii: ")"))
        case .hexString(let bytes):
            out.append(UInt8(ascii: "<"))
            for b in bytes { out.append(contentsOf: Self.asciiBytes(Self.hex2(b))) }
            out.append(UInt8(ascii: ">"))
        case .reference(let n):
            out.append(contentsOf: Self.asciiBytes("\(n) 0 R"))
        case .array(let items):
            out.append(UInt8(ascii: "["))
            for (i, item) in items.enumerated() {
                if i > 0 { out.append(UInt8(ascii: " ")) }
                item.serialize(into: &out)
            }
            out.append(UInt8(ascii: "]"))
        case .dictionary(let pairs):
            Self.serializeDict(pairs, into: &out)
        case .stream(let dict, let data):
            // A stream is a dictionary that MUST carry /Length, followed by the
            // raw bytes between `stream`/`endstream` keywords (§7.3.8).
            var d = dict
            d.append((key: "Length", value: .integer(data.count)))
            Self.serializeDict(d, into: &out)
            out.append(contentsOf: Self.asciiBytes("\nstream\n"))
            out.append(contentsOf: data)
            out.append(contentsOf: Self.asciiBytes("\nendstream"))
        }
    }

    /// Convenience: the serialized bytes of this object.
    public var serializedBytes: [UInt8] {
        var out: [UInt8] = []
        serialize(into: &out)
        return out
    }

    // MARK: - Equatable

    public static func == (lhs: PDFObject, rhs: PDFObject) -> Bool {
        lhs.serializedBytes == rhs.serializedBytes
    }

    // MARK: - Serialization helpers

    private static func serializeDict(_ pairs: [(key: String, value: PDFObject)], into out: inout [UInt8]) {
        out.append(contentsOf: asciiBytes("<< "))
        for (key, value) in pairs {
            out.append(UInt8(ascii: "/"))
            out.append(contentsOf: escapeName(key))
            out.append(UInt8(ascii: " "))
            value.serialize(into: &out)
            out.append(UInt8(ascii: " "))
        }
        out.append(contentsOf: asciiBytes(">>"))
    }

    private static func asciiBytes(_ s: String) -> [UInt8] { Array(s.utf8) }

    private static func hex2(_ b: UInt8) -> String {
        let digits = "0123456789ABCDEF"
        let hi = digits[digits.index(digits.startIndex, offsetBy: Int(b >> 4))]
        let lo = digits[digits.index(digits.startIndex, offsetBy: Int(b & 0xF))]
        return "\(hi)\(lo)"
    }

    /// Locale-independent compact real (§7.3.3). No exponent, trimmed zeros.
    static func formatReal(_ r: Double) -> String {
        if r == r.rounded() && abs(r) < 1e15 { return String(Int(r)) }
        // Fixed 5-decimal then trim — avoids locale decimal separators and
        // scientific notation that some `Double` descriptions produce.
        let scaled = (r * 100000).rounded()
        let intPart = Int(scaled / 100000)
        let frac = abs(Int(scaled)) % 100000
        if frac == 0 { return String(intPart) }
        var digits = String(format0(frac, width: 5))
        while digits.hasSuffix("0") { digits.removeLast() }
        let sign = (r < 0 && intPart == 0) ? "-" : ""
        return "\(sign)\(intPart).\(digits)"
    }

    private static func format0(_ value: Int, width: Int) -> String {
        var s = String(value)
        while s.count < width { s = "0" + s }
        return s
    }

    private static func escapeName(_ name: String) -> [UInt8] {
        // §7.3.5: characters outside the regular set are written as #XX.
        var out: [UInt8] = []
        for b in name.utf8 {
            let isRegular = (b > 0x20 && b < 0x7F)
                && b != UInt8(ascii: "/") && b != UInt8(ascii: "#")
                && b != UInt8(ascii: "(") && b != UInt8(ascii: ")")
                && b != UInt8(ascii: "<") && b != UInt8(ascii: ">")
                && b != UInt8(ascii: "[") && b != UInt8(ascii: "]")
                && b != UInt8(ascii: "{") && b != UInt8(ascii: "}")
                && b != UInt8(ascii: "%")
            if isRegular {
                out.append(b)
            } else {
                out.append(UInt8(ascii: "#"))
                out.append(contentsOf: asciiBytes(hex2(b)))
            }
        }
        return out
    }

    private static func escapeLiteralString(_ s: String) -> [UInt8] {
        // §7.3.4.2: escape ( ) and backslash; emit Latin-1 bytes.
        var out: [UInt8] = []
        for scalar in s.unicodeScalars {
            let v = scalar.value
            let b: UInt8 = v <= 0xFF ? UInt8(v) : UInt8(ascii: "?")
            switch b {
            case UInt8(ascii: "("), UInt8(ascii: ")"), UInt8(ascii: "\\"):
                out.append(UInt8(ascii: "\\"))
                out.append(b)
            default:
                out.append(b)
            }
        }
        return out
    }
}

// MARK: - Ergonomic builders

extension PDFObject {
    /// Build a dictionary from ordered pairs.
    public static func dict(_ pairs: [(String, PDFObject)]) -> PDFObject {
        .dictionary(pairs.map { (key: $0.0, value: $0.1) })
    }

    /// Build a stream from an ordered dictionary and raw bytes.
    public static func streamObject(_ pairs: [(String, PDFObject)], _ data: [UInt8]) -> PDFObject {
        .stream(dict: pairs.map { (key: $0.0, value: $0.1) }, data: data)
    }
}
