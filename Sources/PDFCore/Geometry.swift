// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import Foundation

/// A point in PDF user space (origin bottom-left, units = points).
public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public static let zero = Point(x: 0, y: 0)
}

/// A width/height pair in points.
public struct Size: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    public static let zero = Size(width: 0, height: 0)
}

/// An axis-aligned rectangle (origin = lower-left corner).
public struct Rectangle: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public init(origin: Point, size: Size) {
        self.init(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }

    public var origin: Point { Point(x: x, y: y) }
    public var size: Size { Size(width: width, height: height) }
    public var minX: Double { Swift.min(x, x + width) }
    public var maxX: Double { Swift.max(x, x + width) }
    public var minY: Double { Swift.min(y, y + height) }
    public var maxY: Double { Swift.max(y, y + height) }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}

/// A 2D affine transform `[a b c d tx ty]` matching the PDF `cm` operator.
/// A point maps as `(a·x + c·y + tx, b·x + d·y + ty)`.
public struct AffineTransform: Equatable, Sendable {
    public var a, b, c, d, tx, ty: Double

    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }

    public static let identity = AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    public init(translationX dx: Double, y dy: Double) {
        self.init(a: 1, b: 0, c: 0, d: 1, tx: dx, ty: dy)
    }
    public init(scaleX sx: Double, y sy: Double) {
        self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0)
    }
    /// Rotation by `angle` radians counterclockwise.
    public init(rotationAngle angle: Double) {
        let cs = cos(angle), sn = sin(angle)
        self.init(a: cs, b: sn, c: -sn, d: cs, tx: 0, ty: 0)
    }

    /// Matrix product `self × other`: apply `self` first, then `other`.
    public func concatenating(_ m: AffineTransform) -> AffineTransform {
        AffineTransform(
            a: a * m.a + b * m.c,
            b: a * m.b + b * m.d,
            c: c * m.a + d * m.c,
            d: c * m.b + d * m.d,
            tx: tx * m.a + ty * m.c + m.tx,
            ty: tx * m.b + ty * m.d + m.ty
        )
    }

    public func apply(to p: Point) -> Point {
        Point(x: a * p.x + c * p.y + tx, y: b * p.x + d * p.y + ty)
    }
}
