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
        var font: StandardFont?
        var embedded: EmbeddedFont?
        var fontSize: Double = 12
        var fontResource: String?
    }

    private let page: PDFPage?
    private var content: [UInt8] = []
    private var state = State()
    private var stack: [State] = []

    init(page: PDFPage?) {
        self.page = page
    }

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

    // MARK: - Images

    /// Draw `image` to fill `rect` (in page coordinates). Registers the image as
    /// a page XObject resource and emits the placement operators.
    public func draw(_ image: PDFImageData, in rect: Rectangle) {
        let name = page?.imageResourceName(for: image) ?? "Im1"
        saveState()
        // Map the image's unit square onto rect.
        concatenate(AffineTransform(a: rect.width, b: 0, c: 0, d: rect.height, tx: rect.x, ty: rect.y))
        emit("/\(name) Do")
        restoreState()
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

    // MARK: - Text

    /// Select the font and size used by subsequent `show` calls. Registers the
    /// font as a page resource.
    public func setFont(_ font: StandardFont, size: Double) {
        state.font = font
        state.embedded = nil
        state.fontSize = size
        state.fontResource = page?.resourceName(for: font) ?? "F1"
    }

    /// Select an embedded (TTF/OTF) font and size for subsequent `show` calls.
    public func setFont(_ font: EmbeddedFont, size: Double) {
        state.embedded = font
        state.font = nil
        state.fontSize = size
        state.fontResource = page?.resourceName(for: font) ?? "F1"
    }

    /// Draw `text` with the current font, with its baseline origin at `point`.
    /// `setFont(_:size:)` must have been called first.
    ///
    /// In this milestone only printable ASCII is encoded; characters outside
    /// `0x20…0x7E` are dropped (WinAnsi high range arrives with the text layer's
    /// encoding work).
    public func show(_ text: String, at point: Point) {
        guard let resource = state.fontResource else {
            preconditionFailure("setFont(_:size:) must be called before show(_:at:)")
        }
        emit("BT")
        emit("/\(resource) \(num(state.fontSize)) Tf")
        emit("\(num(point.x)) \(num(point.y)) Td")
        var line: [UInt8] = []
        if let embedded = state.embedded {
            let (operand, _) = embedded.encode(text, size: state.fontSize)
            if embedded.usesHexString {
                PDFObject.hexString(operand).serialize(into: &line)
            } else {
                PDFObject.string(String(decoding: operand, as: UTF8.self)).serialize(into: &line)
            }
        } else {
            PDFObject.string(encodableASCII(text)).serialize(into: &line)
        }
        line.append(contentsOf: Array(" Tj".utf8))
        emitRaw(line)
        emit("ET")
    }

    /// The advance width of `text` in the given font and size (points).
    public func textWidth(_ text: String, font: StandardFont, size: Double) -> Double {
        font.width(of: text, size: size)
    }

    /// The advance width of `text` in the current font/size (points).
    public func textWidth(_ text: String) -> Double {
        if let embedded = state.embedded {
            return embedded.width(of: text, size: state.fontSize)
        }
        guard let font = state.font else { return 0 }
        return textWidth(text, font: font, size: state.fontSize)
    }

    /// Drop characters outside printable ASCII for now (M4 limitation).
    private func encodableASCII(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0.value >= 0x20 && $0.value <= 0x7E }))
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

    private func emitRaw(_ bytes: [UInt8]) {
        content.append(contentsOf: bytes)
        content.append(0x0A)
    }

    private func num(_ v: Double) -> String { PDFObject.formatReal(v) }
}

extension PDFPage {
    /// Draw onto this page. Operators recorded by the closure are appended to
    /// the page content (multiple `draw` calls accumulate).
    public func draw(_ body: (DrawingContext) -> Void) {
        let ctx = DrawingContext(page: self)
        body(ctx)
        content.append(contentsOf: ctx.finish())
    }
}
