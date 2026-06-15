// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT
//
// Original work implementing PDF file structure per ISO 32000-1 (§7.5).
// Not derived from libharu.

import Foundation

/// Assembles indirect objects into a complete PDF file: header, body (each
/// object wrapped in `N 0 obj … endobj` with its byte offset recorded), the
/// cross-reference table, and the trailer (ISO 32000-1, §7.5). Classic xref
/// table form (no xref streams / object streams yet).
public final class PDFWriter {
    /// Reserved slots; index 0 is object number 1. `nil` = reserved but unset.
    private var objects: [PDFObject?] = []

    public init() {}

    /// Reserve an object number up front so two objects can reference each
    /// other (e.g. a Page's /Parent and the Pages /Kids).
    public func reserve() -> Int {
        objects.append(nil)
        return objects.count
    }

    /// Fill a previously reserved object number.
    public func set(_ number: Int, _ object: PDFObject) {
        precondition(number >= 1 && number <= objects.count, "object number out of range")
        objects[number - 1] = object
    }

    /// Reserve + set in one call, returning the new object number.
    @discardableResult
    public func add(_ object: PDFObject) -> Int {
        let n = reserve()
        set(n, object)
        return n
    }

    /// Number of objects allocated so far (excluding the free object 0).
    public var objectCount: Int { objects.count }

    /// Serialize the whole file. `rootRef` is the object number of the document
    /// catalog; `infoRef`, if given, is the /Info dictionary. Traps if any
    /// reserved object was never set (a wiring bug we want to fail loudly on,
    /// not emit a corrupt PDF).
    public func build(rootRef: Int, infoRef: Int? = nil) -> Data {
        var out: [UInt8] = []

        // Header. The binary-comment second line marks the file as binary so
        // naive text transports don't mangle it (§7.5.2).
        out.append(contentsOf: Array("%PDF-1.7\n".utf8))
        out.append(contentsOf: [UInt8(ascii: "%"), 0xE2, 0xE3, 0xCF, 0xD3, UInt8(ascii: "\n")])

        // Body: record the byte offset of each `N 0 obj` for the xref table.
        var offsets: [Int] = []
        for (i, maybe) in objects.enumerated() {
            guard let object = maybe else {
                fatalError("PDFWriter: object \(i + 1) was reserved but never set")
            }
            offsets.append(out.count)
            out.append(contentsOf: Array("\(i + 1) 0 obj\n".utf8))
            object.serialize(into: &out)
            out.append(contentsOf: Array("\nendobj\n".utf8))
        }

        // Cross-reference table. Entry 0 heads the free list; every other entry
        // is a 20-byte record pointing at its object's byte offset.
        let xrefOffset = out.count
        let count = objects.count + 1
        out.append(contentsOf: Array("xref\n0 \(count)\n".utf8))
        out.append(contentsOf: Array("0000000000 65535 f \n".utf8))
        for offset in offsets {
            out.append(contentsOf: Array(Self.xrefEntry(offset).utf8))
        }

        // Trailer.
        out.append(contentsOf: Array("trailer\n".utf8))
        var trailerPairs: [(String, PDFObject)] = [
            ("Size", .integer(count)),
            ("Root", .reference(rootRef)),
        ]
        if let infoRef { trailerPairs.append(("Info", .reference(infoRef))) }
        out.append(contentsOf: PDFObject.dict(trailerPairs).serializedBytes)
        out.append(contentsOf: Array("\nstartxref\n\(xrefOffset)\n%%EOF\n".utf8))

        return Data(out)
    }

    /// A 20-byte in-use xref entry: 10-digit offset, gen 0, type `n`, EOL.
    private static func xrefEntry(_ offset: Int) -> String {
        var s = String(offset)
        while s.count < 10 { s = "0" + s }
        return "\(s) 00000 n \n"
    }
}
