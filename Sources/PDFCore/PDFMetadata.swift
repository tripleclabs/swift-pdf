// Copyright (c) 2026 the swift-pdf authors.
// SPDX-License-Identifier: MIT

import Foundation

/// Document information dictionary (ISO 32000-1, §14.3.3). All fields optional
/// except `producer`, which defaults to identifying this library. Dates are
/// emitted only when set, keeping output deterministic by default.
public struct PDFMetadata: Equatable, Sendable {
    public var title: String?
    public var author: String?
    public var subject: String?
    public var keywords: String?
    public var creator: String?
    public var producer: String?
    public var creationDate: Date?
    public var modificationDate: Date?
    /// Time zone used to format the dates above (default UTC).
    public var timeZone: TimeZone

    public init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: String? = nil,
        creator: String? = nil,
        producer: String? = "swift-pdf",
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
        self.creator = creator
        self.producer = producer
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.timeZone = timeZone
    }

    /// The ordered `/Info` dictionary pairs, omitting unset fields.
    var infoDictionaryPairs: [(String, PDFObject)] {
        var pairs: [(String, PDFObject)] = []
        func add(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { pairs.append((key, .string(value))) }
        }
        add("Title", title)
        add("Author", author)
        add("Subject", subject)
        add("Keywords", keywords)
        add("Creator", creator)
        add("Producer", producer)
        if let creationDate {
            pairs.append(("CreationDate", .string(PDFDateFormat.string(from: creationDate, timeZone: timeZone))))
        }
        if let modificationDate {
            pairs.append(("ModDate", .string(PDFDateFormat.string(from: modificationDate, timeZone: timeZone))))
        }
        return pairs
    }
}

/// Formats a `Date` as a PDF date string `D:YYYYMMDDHHmmSSOHH'mm'` (§7.9.4).
enum PDFDateFormat {
    static func string(from date: Date, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "'D:'yyyyMMddHHmmss"
        var s = f.string(from: date)
        let offset = timeZone.secondsFromGMT(for: date)
        if offset == 0 {
            s += "Z00'00'"
        } else {
            let sign = offset > 0 ? "+" : "-"
            let mag = abs(offset)
            s += String(format: "%@%02d'%02d'", sign, mag / 3600, (mag % 3600) / 60)
        }
        return s
    }
}
