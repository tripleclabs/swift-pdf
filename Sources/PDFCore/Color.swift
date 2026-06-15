// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// A color in one of the three device color spaces. Components are clamped to
/// `0...1`. Stroking and non-stroking (fill) variants emit different operators.
public enum PDFColor: Equatable, Sendable {
    case gray(Double)
    case rgb(red: Double, green: Double, blue: Double)
    case cmyk(cyan: Double, magenta: Double, yellow: Double, black: Double)

    public static let black = PDFColor.gray(0)
    public static let white = PDFColor.gray(1)
    public static let red = PDFColor.rgb(red: 1, green: 0, blue: 0)
    public static let green = PDFColor.rgb(red: 0, green: 1, blue: 0)
    public static let blue = PDFColor.rgb(red: 0, green: 0, blue: 1)

    private static func clamp(_ v: Double) -> Double { Swift.min(1, Swift.max(0, v)) }

    /// Content-stream operator setting this as the stroking color.
    func strokeOperator() -> String {
        switch self {
        case .gray(let g):
            return "\(num(g)) G"
        case .rgb(let r, let gr, let b):
            return "\(num(r)) \(num(gr)) \(num(b)) RG"
        case .cmyk(let c, let m, let y, let k):
            return "\(num(c)) \(num(m)) \(num(y)) \(num(k)) K"
        }
    }

    /// Content-stream operator setting this as the non-stroking (fill) color.
    func fillOperator() -> String {
        switch self {
        case .gray(let g):
            return "\(num(g)) g"
        case .rgb(let r, let gr, let b):
            return "\(num(r)) \(num(gr)) \(num(b)) rg"
        case .cmyk(let c, let m, let y, let k):
            return "\(num(c)) \(num(m)) \(num(y)) \(num(k)) k"
        }
    }

    private func num(_ v: Double) -> String { PDFObject.formatReal(Self.clamp(v)) }
}
