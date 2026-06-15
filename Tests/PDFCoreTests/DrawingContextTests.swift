// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
@testable import PDFCore

final class DrawingContextTests: XCTestCase {

    /// Draw on a page and return the resulting content-stream text.
    private func content(_ body: (DrawingContext) -> Void) -> String {
        let page = PDFPage(size: .a4)
        page.draw(body)
        return String(decoding: page.content, as: UTF8.self)
    }

    func testFillRectEmitsColorPathAndPaintOperators() {
        let s = content { ctx in
            ctx.setFillColor(.red)
            ctx.fill(Path.rect(Rectangle(x: 10, y: 20, width: 100, height: 50)))
        }
        XCTAssertTrue(s.contains("1 0 0 rg"))            // red fill color
        XCTAssertTrue(s.contains("10 20 100 50 re"))     // rectangle
        XCTAssertTrue(s.contains("\nf\n"))               // nonzero fill
    }

    func testStrokeAndLineAttributes() {
        let s = content { ctx in
            ctx.setStrokeColor(.gray(0.5))
            ctx.setLineWidth(2.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.bevel)
            ctx.stroke(Path.line(from: .zero, to: Point(x: 100, y: 100)))
        }
        XCTAssertTrue(s.contains("0.5 G"))
        XCTAssertTrue(s.contains("2.5 w"))
        XCTAssertTrue(s.contains("1 J"))
        XCTAssertTrue(s.contains("2 j"))
        XCTAssertTrue(s.contains("0 0 m"))
        XCTAssertTrue(s.contains("100 100 l"))
        XCTAssertTrue(s.contains("\nS\n"))
    }

    func testCmykAndEvenOddFill() {
        let s = content { ctx in
            ctx.setFillColor(.cmyk(cyan: 0, magenta: 1, yellow: 1, black: 0))
            ctx.fill(Path.circle(center: Point(x: 50, y: 50), radius: 25), rule: .evenOdd)
        }
        XCTAssertTrue(s.contains("0 1 1 0 k"))
        XCTAssertTrue(s.contains(" c\n"))                // at least one bezier
        XCTAssertTrue(s.contains("\nf*\n"))              // even-odd fill
    }

    func testTransformsEmitCm() {
        let s = content { ctx in
            ctx.translate(x: 100, y: 200)
            ctx.scale(x: 2, y: 2)
        }
        XCTAssertTrue(s.contains("1 0 0 1 100 200 cm"))
        XCTAssertTrue(s.contains("2 0 0 2 0 0 cm"))
    }

    func testSaveRestoreAndScopedClip() {
        let s = content { ctx in
            ctx.withState {
                ctx.setFillColor(.blue)
            }
            ctx.clip(to: Path.rect(Rectangle(x: 0, y: 0, width: 10, height: 10))) {
                ctx.fill(Path.rect(Rectangle(x: 0, y: 0, width: 100, height: 100)))
            }
        }
        // withState wraps in q/Q.
        XCTAssertTrue(s.contains("\nq\n"))
        XCTAssertTrue(s.contains("\nQ\n"))
        // clip emits W then n inside a q/Q scope.
        XCTAssertTrue(s.contains("0 0 10 10 re"))
        XCTAssertTrue(s.contains("\nW\n"))
        XCTAssertTrue(s.contains("\nn\n"))
    }

    func testMultipleDrawCallsAccumulate() {
        let page = PDFPage(size: .a4)
        page.draw { $0.fill(Path.rect(Rectangle(x: 0, y: 0, width: 1, height: 1))) }
        page.draw { $0.stroke(Path.line(from: .zero, to: Point(x: 1, y: 1))) }
        let s = String(decoding: page.content, as: UTF8.self)
        XCTAssertTrue(s.contains("\nf\n") && s.contains("\nS\n"))
    }
}
