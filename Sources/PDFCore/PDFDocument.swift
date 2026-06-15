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

        var kids: [PDFObject] = []
        for page in pages {
            let contentObj = writer.add(.streamObject([], page.content))
            let pageObj = writer.add(.dict([
                ("Type", .name("Page")),
                ("Parent", .reference(pagesNode)),
                ("MediaBox", .array([
                    .real(0), .real(0), .real(page.size.width), .real(page.size.height),
                ])),
                ("Resources", .dict([])),
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
}
