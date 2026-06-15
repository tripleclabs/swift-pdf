// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftPDF

/// Builders for the showcase PDFs. Each returns (filename, document).
enum Samples {
    static let all: [(name: String, make: @Sendable () -> PDFDocument)] = [
        ("01-fonts", fonts),
        ("02-graphics", graphics),
        ("03-transforms", transforms),
        ("04-report", report),
    ]

    // MARK: - Shared helpers

    private static let letter = PDFPageSize.letter
    private static let margin = 60.0

    /// Draw a left-aligned line; return the baseline y for the next line.
    @discardableResult
    private static func text(_ ctx: DrawingContext, _ s: String, _ font: StandardFont,
                             _ size: Double, x: Double, y: Double,
                             color: PDFColor = .black) -> Double {
        ctx.setFillColor(color)
        ctx.setFont(font, size: size)
        ctx.show(s, at: Point(x: x, y: y))
        return y - size * 1.35
    }

    /// A heading with an accent rule sized to the text width (uses textWidth).
    private static func heading(_ ctx: DrawingContext, _ s: String, x: Double, y: Double) -> Double {
        let size = 22.0
        ctx.setFont(.helveticaBold, size: size)
        let w = ctx.textWidth(s, font: .helveticaBold, size: size)
        ctx.setFillColor(.rgb(red: 0.10, green: 0.12, blue: 0.16))
        ctx.show(s, at: Point(x: x, y: y))
        ctx.setFillColor(.rgb(red: 0.20, green: 0.45, blue: 0.95))
        ctx.fill(Path.rect(Rectangle(x: x, y: y - 8, width: w, height: 3)))
        return y - 40
    }

    // MARK: - 01 Fonts

    private static func fonts() -> PDFDocument {
        let doc = PDFDocument(metadata: PDFMetadata(title: "swift-pdf — Standard 14 Fonts"))
        let page = doc.addPage(size: letter)
        page.draw { ctx in
            var y = heading(ctx, "Standard 14 Fonts", x: margin, y: letter.height - margin)
            let sample = "The quick brown fox 0123456789"
            for font in StandardFont.allCases {
                _ = text(ctx, font.baseName, .helvetica, 8,
                         x: margin, y: y, color: .gray(0.45))
                // Symbol/ZapfDingbats render the ASCII as their own glyphs.
                _ = text(ctx, font.isSymbolic ? "abcdefg hijklmn 12345" : sample,
                         font, 17, x: margin, y: y - 11)
                y -= 44
            }
        }
        return doc
    }

    // MARK: - 02 Graphics

    private static func graphics() -> PDFDocument {
        let doc = PDFDocument(metadata: PDFMetadata(title: "swift-pdf — Graphics"))
        let page = doc.addPage(size: letter)
        page.draw { ctx in
            var y = heading(ctx, "Graphics", x: margin, y: letter.height - margin)

            // Color swatches (RGB / CMYK / Gray).
            y -= 10
            let swatches: [(String, PDFColor)] = [
                ("RGB", .rgb(red: 0.85, green: 0.20, blue: 0.25)),
                ("CMYK", .cmyk(cyan: 0.8, magenta: 0.1, yellow: 0.2, black: 0)),
                ("Gray", .gray(0.4)),
            ]
            for (i, (label, color)) in swatches.enumerated() {
                let x = margin + Double(i) * 150
                ctx.setFillColor(color)
                ctx.fill(Path.rect(Rectangle(x: x, y: y - 50, width: 120, height: 50)))
                _ = text(ctx, label, .helvetica, 10, x: x, y: y - 64, color: .gray(0.4))
            }
            y -= 110

            // Stroked shapes + line caps.
            ctx.setStrokeColor(.rgb(red: 0.2, green: 0.45, blue: 0.95))
            ctx.setLineWidth(6)
            for (i, cap) in [LineCap.butt, .round, .projectingSquare].enumerated() {
                ctx.setLineCap(cap)
                var p = Path()
                p.move(to: Point(x: margin, y: y - Double(i) * 22))
                p.addLine(to: Point(x: margin + 140, y: y - Double(i) * 22))
                ctx.stroke(p)
            }
            _ = text(ctx, "line caps: butt / round / square", .helvetica, 10,
                     x: margin + 160, y: y - 24, color: .gray(0.4))
            y -= 90

            // Dashed circle (stroke) and even-odd "donut" fill.
            ctx.setLineWidth(2)
            ctx.setStrokeColor(.gray(0.2))
            ctx.setDash(DashPattern(lengths: [8, 4]))
            ctx.stroke(Path.circle(center: Point(x: margin + 60, y: y - 60), radius: 50))
            ctx.setDash(.solid)

            var donut = Path()
            donut.addCircle(center: Point(x: margin + 260, y: y - 60), radius: 50)
            donut.addCircle(center: Point(x: margin + 260, y: y - 60), radius: 25)
            ctx.setFillColor(.rgb(red: 0.95, green: 0.6, blue: 0.1))
            ctx.fill(donut, rule: .evenOdd)   // hole via even-odd rule
            _ = text(ctx, "dashed stroke      even-odd fill (hole)", .helvetica, 10,
                     x: margin, y: y - 130, color: .gray(0.4))
        }
        return doc
    }

    // MARK: - 03 Transforms

    private static func transforms() -> PDFDocument {
        let doc = PDFDocument(metadata: PDFMetadata(title: "swift-pdf — Transforms"))
        let page = doc.addPage(size: letter)
        page.draw { ctx in
            _ = heading(ctx, "Transforms", x: margin, y: letter.height - margin)

            // A fan of rotated, color-graded rectangles around a center.
            let center = Point(x: letter.width / 2, y: 480)
            let count = 24
            for i in 0..<count {
                ctx.withState {
                    ctx.translate(x: center.x, y: center.y)
                    ctx.rotate(Double(i) / Double(count) * 2 * .pi)
                    let hue = Double(i) / Double(count)
                    ctx.setFillColor(.rgb(red: hue, green: 0.3, blue: 1 - hue))
                    ctx.fill(Path.rect(Rectangle(x: 0, y: -6, width: 150, height: 12)))
                }
            }

            // Clipping: fill a band of stripes clipped to a circle.
            let clipCenter = Point(x: letter.width / 2, y: 180)
            ctx.clip(to: Path.circle(center: clipCenter, radius: 90)) {
                for i in 0..<18 {
                    let x = clipCenter.x - 90 + Double(i) * 10
                    ctx.setFillColor(i % 2 == 0 ? .rgb(red: 0.2, green: 0.45, blue: 0.95) : .white)
                    ctx.fill(Path.rect(Rectangle(x: x, y: clipCenter.y - 90, width: 10, height: 180)))
                }
            }
            _ = text(ctx, "rotated fan + stripes clipped to a circle", .helvetica, 10,
                     x: margin, y: 70, color: .gray(0.4))
        }
        return doc
    }

    // MARK: - 04 Report (multi-page, metrics-driven word wrap)

    private static func report() -> PDFDocument {
        let doc = PDFDocument(metadata: PDFMetadata(
            title: "swift-pdf — Sample Report", author: "Triple C Labs GmbH"))

        let body = StandardFont.timesRoman
        let bodySize = 12.0
        let lineHeight = bodySize * 1.4
        let maxWidth = letter.width - margin * 2
        let paragraph =
            "swift-pdf is a pure-Swift PDF generation library. This report is laid out " +
            "by measuring text with the standard-14 font metrics and wrapping words to the " +
            "page width, then flowing paragraphs across multiple pages. No native libraries " +
            "are required for this document — it is produced entirely by the dependency-free core."

        // 1. Lay out all lines up front (pure measurement, no page needed).
        var lines: [String] = []
        for i in 1...9 {
            lines.append(contentsOf: wrap("\(i).  " + paragraph, font: body, size: bodySize, maxWidth: maxWidth))
            lines.append("")   // paragraph gap
        }

        // 2. Chunk into pages. Page 1 has less room because of the heading.
        let bottom = margin + 30
        let firstTop = letter.height - margin - 44
        let nextTop = letter.height - margin
        let firstCap = Int((firstTop - bottom) / lineHeight)
        let nextCap = Int((nextTop - bottom) / lineHeight)
        var pages: [[String]] = []
        var rest = lines[...]
        while !rest.isEmpty {
            let cap = pages.isEmpty ? firstCap : nextCap
            pages.append(Array(rest.prefix(cap)))
            rest = rest.dropFirst(cap)
        }

        // 3. Render each page.
        for (index, pageLines) in pages.enumerated() {
            let page = doc.addPage(size: letter)
            page.draw { ctx in
                var y = nextTop
                if index == 0 { y = heading(ctx, "Sample Report", x: margin, y: letter.height - margin) }
                ctx.setFont(body, size: bodySize)
                for line in pageLines where !line.isEmpty {
                    ctx.setFillColor(.black)
                    ctx.show(line, at: Point(x: margin, y: y))
                    y -= lineHeight
                }
                footer(ctx, page: index + 1)
            }
        }
        return doc
    }

    private static func footer(_ ctx: DrawingContext, page: Int) {
        ctx.setStrokeColor(.gray(0.8))
        ctx.setLineWidth(0.5)
        var rule = Path()
        rule.move(to: Point(x: margin, y: margin))
        rule.addLine(to: Point(x: letter.width - margin, y: margin))
        ctx.stroke(rule)
        _ = text(ctx, "swift-pdf sample report", .helvetica, 9,
                 x: margin, y: margin - 14, color: .gray(0.5))
        ctx.setFont(.helvetica, size: 9)
        let label = "Page \(page)"
        let w = ctx.textWidth(label, font: .helvetica, size: 9)
        ctx.setFillColor(.gray(0.5))
        ctx.show(label, at: Point(x: letter.width - margin - w, y: margin - 14))
    }

    private static func wrap(_ text: String, font: StandardFont,
                             size: Double, maxWidth: Double) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            let trial = current.isEmpty ? String(word) : current + " " + word
            if font.width(of: trial, size: size) <= maxWidth {
                current = trial
            } else {
                if !current.isEmpty { lines.append(current) }
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}
