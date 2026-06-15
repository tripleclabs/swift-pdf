// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
@testable import PDFCore

final class GeometryTests: XCTestCase {

    private func assertPoint(_ a: Point, _ b: Point, accuracy: Double = 1e-9) {
        XCTAssertEqual(a.x, b.x, accuracy: accuracy)
        XCTAssertEqual(a.y, b.y, accuracy: accuracy)
    }

    func testIdentityApply() {
        assertPoint(AffineTransform.identity.apply(to: Point(x: 3, y: 4)), Point(x: 3, y: 4))
    }

    func testTranslation() {
        let t = AffineTransform(translationX: 10, y: -5)
        assertPoint(t.apply(to: Point(x: 1, y: 1)), Point(x: 11, y: -4))
    }

    func testScale() {
        let t = AffineTransform(scaleX: 2, y: 3)
        assertPoint(t.apply(to: Point(x: 4, y: 5)), Point(x: 8, y: 15))
    }

    func testRotation90() {
        let t = AffineTransform(rotationAngle: .pi / 2)
        assertPoint(t.apply(to: Point(x: 1, y: 0)), Point(x: 0, y: 1), accuracy: 1e-12)
    }

    func testConcatenationOrderIsSelfThenOther() {
        // Scale by 2 then translate by (10,0): (1,1) -> (2,2) -> (12,2).
        let t = AffineTransform(scaleX: 2, y: 2)
            .concatenating(AffineTransform(translationX: 10, y: 0))
        assertPoint(t.apply(to: Point(x: 1, y: 1)), Point(x: 12, y: 2))
    }

    func testRectangleAccessors() {
        let r = Rectangle(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(r.maxX, 110)
        XCTAssertEqual(r.maxY, 70)
        XCTAssertEqual(r.midX, 60)
        XCTAssertEqual(r.midY, 45)
    }

    func testEllipseShape() {
        let p = Path.ellipse(in: Rectangle(x: 0, y: 0, width: 100, height: 100))
        // move + 4 curves + close.
        XCTAssertEqual(p.elements.count, 6)
        if case .move = p.elements.first {} else { XCTFail("starts with move") }
        if case .close = p.elements.last {} else { XCTFail("ends with close") }
    }
}
