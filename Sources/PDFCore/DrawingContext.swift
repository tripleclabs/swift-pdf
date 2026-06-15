// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// Records page content as PDF content-stream operators (ISO 32000-1, §8–9).
/// Obtained via `PDFPage.draw { ctx in … }`; its output is appended to the
/// page's content when the closure returns.
public final class DrawingContext {

    /// Tracked graphics state (for save/restore and future getters).
    struct State {
        var strokeColor: PDFColor = .black
        var fillColor: PDFColor = .black
        var lineWidth: Double = 1
    }

    private var content: [UInt8] = []
    private var state = State()
    private var stack: [State] = []

    init() {}

    /// The accumulated content-stream bytes.
    func finish() -> [UInt8] {
        precondition(stack.isEmpty, "unbalanced saveState()/restoreState()")
        return content
    }

    // MARK: - Graphics state

    public func saveState() {
        emit("q")
        stack.append(state)
    }

    public func restoreState() {
        precondition(!stack.isEmpty, "restoreState() without matching saveState()")
        emit("Q")
        state = stack.removeLast()
    }

    /// Run `body` between a save/restore pair so its state changes are scoped.
    public func withState(_ body: () -> Void) {
        saveState()
        body()
        restoreState()
    }

    // MARK: - Attributes

    public func setStrokeColor(_ color: PDFColor) {
        emit(color.strokeOperator())
        state.strokeColor = color
    }
    public func setFillColor(_ color: PDFColor) {
        emit(color.fillOperator())
        state.fillColor = color
    }
    public func setLineWidth(_ width: Double) {
        emit("\(num(width)) w")
        state.lineWidth = width
    }
    public func setLineCap(_ cap: LineCap) { emit("\(cap.rawValue) J") }
    public func setLineJoin(_ join: LineJoin) { emit("\(join.rawValue) j") }
    public func setDash(_ dash: DashPattern) {
        let lengths = dash.lengths.map(num).joined(separator: " ")
        emit("[\(lengths)] \(num(dash.phase)) d")
    }

    // MARK: - Transforms

    public func concatenate(_ t: AffineTransform) {
        emit("\(num(t.a)) \(num(t.b)) \(num(t.c)) \(num(t.d)) \(num(t.tx)) \(num(t.ty)) cm")
    }
    public func translate(x: Double, y: Double) {
        concatenate(AffineTransform(translationX: x, y: y))
    }
    public func scale(x: Double, y: Double) {
        concatenate(AffineTransform(scaleX: x, y: y))
    }
    public func rotate(_ angle: Double) {
        concatenate(AffineTransform(rotationAngle: angle))
    }

    // MARK: - Painting

    public func stroke(_ path: Path) {
        emitPath(path); emit("S")
    }
    public func fill(_ path: Path, rule: FillRule = .nonZero) {
        emitPath(path); emit(rule == .evenOdd ? "f*" : "f")
    }
    public func fillAndStroke(_ path: Path, rule: FillRule = .nonZero) {
        emitPath(path); emit(rule == .evenOdd ? "B*" : "B")
    }

    /// Intersect the clip region with `path` for the duration of `body`
    /// (scoped by an implicit save/restore).
    public func clip(to path: Path, rule: FillRule = .nonZero, _ body: () -> Void) {
        saveState()
        emitPath(path)
        emit(rule == .evenOdd ? "W*" : "W")
        emit("n")   // end the path without painting it
        body()
        restoreState()
    }

    // MARK: - Internals

    /// Internal access for the text layer (M4) to append raw operators.
    func appendOperator(_ s: String) { emit(s) }

    private func emitPath(_ path: Path) {
        for element in path.elements {
            switch element {
            case .move(let p):
                emit("\(num(p.x)) \(num(p.y)) m")
            case .line(let p):
                emit("\(num(p.x)) \(num(p.y)) l")
            case .curve(let c1, let c2, let end):
                emit("\(num(c1.x)) \(num(c1.y)) \(num(c2.x)) \(num(c2.y)) \(num(end.x)) \(num(end.y)) c")
            case .rect(let r):
                emit("\(num(r.x)) \(num(r.y)) \(num(r.width)) \(num(r.height)) re")
            case .close:
                emit("h")
            }
        }
    }

    private func emit(_ s: String) {
        content.append(contentsOf: Array(s.utf8))
        content.append(0x0A)   // newline
    }

    private func num(_ v: Double) -> String { PDFObject.formatReal(v) }
}

extension PDFPage {
    /// Draw onto this page. Operators recorded by the closure are appended to
    /// the page content (multiple `draw` calls accumulate).
    public func draw(_ body: (DrawingContext) -> Void) {
        let ctx = DrawingContext()
        body(ctx)
        content.append(contentsOf: ctx.finish())
    }
}
