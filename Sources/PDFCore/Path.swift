// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// A vector path recorded as a value-typed list of construction elements, then
/// flushed to PDF path operators when drawn (the deferred-drawing model). This
/// keeps drawing pure and the API free of any live context handle.
public struct Path: Equatable, Sendable {
    enum Element: Equatable, Sendable {
        case move(Point)
        case line(Point)
        case curve(control1: Point, control2: Point, end: Point)
        case rect(Rectangle)
        case close
    }

    private(set) var elements: [Element] = []

    public init() {}

    public var isEmpty: Bool { elements.isEmpty }

    // MARK: - Mutating construction

    public mutating func move(to p: Point) { elements.append(.move(p)) }
    public mutating func addLine(to p: Point) { elements.append(.line(p)) }
    public mutating func addCurve(to end: Point, control1: Point, control2: Point) {
        elements.append(.curve(control1: control1, control2: control2, end: end))
    }
    public mutating func close() { elements.append(.close) }
    public mutating func addRect(_ r: Rectangle) { elements.append(.rect(r)) }

    /// Append an ellipse inscribed in `rect`, approximated by four cubic Béziers.
    public mutating func addEllipse(in rect: Rectangle) {
        let kappa = 0.5522847498307936
        let ox = rect.width / 2 * kappa   // control offset, horizontal
        let oy = rect.height / 2 * kappa  // control offset, vertical
        let cx = rect.midX, cy = rect.midY
        let left = rect.minX, right = rect.maxX, top = rect.maxY, bottom = rect.minY

        move(to: Point(x: left, y: cy))
        addCurve(to: Point(x: cx, y: top),
                 control1: Point(x: left, y: cy + oy), control2: Point(x: cx - ox, y: top))
        addCurve(to: Point(x: right, y: cy),
                 control1: Point(x: cx + ox, y: top), control2: Point(x: right, y: cy + oy))
        addCurve(to: Point(x: cx, y: bottom),
                 control1: Point(x: right, y: cy - oy), control2: Point(x: cx + ox, y: bottom))
        addCurve(to: Point(x: left, y: cy),
                 control1: Point(x: cx - ox, y: bottom), control2: Point(x: left, y: cy - oy))
        close()
    }

    public mutating func addCircle(center: Point, radius: Double) {
        addEllipse(in: Rectangle(x: center.x - radius, y: center.y - radius,
                                 width: radius * 2, height: radius * 2))
    }

    // MARK: - Non-mutating factories

    public static func line(from a: Point, to b: Point) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }
    public static func rect(_ r: Rectangle) -> Path {
        var p = Path(); p.addRect(r); return p
    }
    public static func ellipse(in r: Rectangle) -> Path {
        var p = Path(); p.addEllipse(in: r); return p
    }
    public static func circle(center: Point, radius: Double) -> Path {
        var p = Path(); p.addCircle(center: center, radius: radius); return p
    }
}
