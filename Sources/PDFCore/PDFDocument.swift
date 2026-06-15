// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import Foundation

/// A PDF document: a mutable accumulator of pages plus metadata, rendered to
/// bytes on demand. The top-level public entry point.
///
/// Not `Sendable` — build a document on a single task, then call `data()`.
public final class PDFDocument {
    /// Document information dictionary.
    public var metadata: PDFMetadata

    /// The pages, in order.
    public private(set) var pages: [PDFPage] = []

    /// Optional stream compressor. When set (e.g. to a `FlateCompressor`),
    /// stream payloads are compressed if that yields smaller output.
    public var compressor: StreamCompressor?

    public init(metadata: PDFMetadata = PDFMetadata()) {
        self.metadata = metadata
    }

    /// Append a new page of the given size and return it (to draw on later).
    @discardableResult
    public func addPage(size: PDFPageSize = .a4) -> PDFPage {
        let page = PDFPage(size: size)
        pages.append(page)
        return page
    }

    /// Render the document to PDF bytes.
    public func data() -> Data {
        let writer = PDFWriter()

        // Catalog + page tree root are mutually referenced by each page.
        let catalog = writer.reserve()
        let pagesNode = writer.reserve()

        // Build each unique font once per document; pages reference by name.
        var standardFontObjByBase: [String: Int] = [:]
        var embeddedFontObjByKey: [String: Int] = [:]
        func objectNumber(for ref: PDFPage.FontRef) -> Int {
            switch ref {
            case .standard(let font):
                if let n = standardFontObjByBase[font.baseName] { return n }
                let n = writer.add(font.fontDictionary())
                standardFontObjByBase[font.baseName] = n
                return n
            case .embedded(let font):
                if let n = embeddedFontObjByKey[font.fontKey] { return n }
                let n = font.buildFontObject(into: writer)
                embeddedFontObjByKey[font.fontKey] = n
                return n
            }
        }

        var kids: [PDFObject] = []
        for page in pages {
            let contentObj = writer.add(makeStream([], page.content))

            var resourcePairs: [(String, PDFObject)] = []
            if !page.fonts.isEmpty {
                var fontSubdict: [(String, PDFObject)] = []
                for (name, ref) in page.fonts {
                    fontSubdict.append((name, .reference(objectNumber(for: ref))))
                }
                resourcePairs.append(("Font", .dict(fontSubdict)))
            }

            let pageObj = writer.add(.dict([
                ("Type", .name("Page")),
                ("Parent", .reference(pagesNode)),
                ("MediaBox", .array([
                    .real(0), .real(0), .real(page.size.width), .real(page.size.height),
                ])),
                ("Resources", .dict(resourcePairs)),
                ("Contents", .reference(contentObj)),
            ]))
            kids.append(.reference(pageObj))
        }

        writer.set(pagesNode, .dict([
            ("Type", .name("Pages")),
            ("Kids", .array(kids)),
            ("Count", .integer(pages.count)),
        ]))
        writer.set(catalog, .dict([
            ("Type", .name("Catalog")),
            ("Pages", .reference(pagesNode)),
        ]))

        var infoRef: Int?
        let infoPairs = metadata.infoDictionaryPairs
        if !infoPairs.isEmpty {
            infoRef = writer.add(.dict(infoPairs))
        }

        return writer.build(rootRef: catalog, infoRef: infoRef)
    }

    /// Build a stream object, applying `compressor` when it produces something
    /// smaller than the raw payload.
    private func makeStream(_ extra: [(String, PDFObject)], _ data: [UInt8]) -> PDFObject {
        if let compressor, let result = compressor.compress(data), result.bytes.count < data.count {
            return .streamObject(extra + [("Filter", .name(result.filter))], result.bytes)
        }
        return .streamObject(extra, data)
    }
}
