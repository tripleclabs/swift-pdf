// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// One of the 14 standard PDF fonts, which conforming readers provide without
/// embedding. Latin text fonts use WinAnsiEncoding; Symbol/ZapfDingbats use
/// their built-in font-specific encoding.
public enum StandardFont: Sendable, CaseIterable, Equatable {
    case helvetica, helveticaBold, helveticaOblique, helveticaBoldOblique
    case timesRoman, timesBold, timesItalic, timesBoldItalic
    case courier, courierBold, courierOblique, courierBoldOblique
    case symbol, zapfDingbats

    /// The PostScript name used for `/BaseFont`.
    public var baseName: String {
        switch self {
        case .helvetica: return "Helvetica"
        case .helveticaBold: return "Helvetica-Bold"
        case .helveticaOblique: return "Helvetica-Oblique"
        case .helveticaBoldOblique: return "Helvetica-BoldOblique"
        case .timesRoman: return "Times-Roman"
        case .timesBold: return "Times-Bold"
        case .timesItalic: return "Times-Italic"
        case .timesBoldItalic: return "Times-BoldItalic"
        case .courier: return "Courier"
        case .courierBold: return "Courier-Bold"
        case .courierOblique: return "Courier-Oblique"
        case .courierBoldOblique: return "Courier-BoldOblique"
        case .symbol: return "Symbol"
        case .zapfDingbats: return "ZapfDingbats"
        }
    }

    /// Symbol/ZapfDingbats use a font-specific encoding (not WinAnsi).
    public var isSymbolic: Bool { self == .symbol || self == .zapfDingbats }

    private var table: (widths: [Int], ascender: Int, descender: Int, capHeight: Int) {
        switch self {
        case .helvetica: return (Base14Metrics.helveticaWidths, Base14Metrics.helveticaAscender, Base14Metrics.helveticaDescender, Base14Metrics.helveticaCapHeight)
        case .helveticaBold: return (Base14Metrics.helveticaBoldWidths, Base14Metrics.helveticaBoldAscender, Base14Metrics.helveticaBoldDescender, Base14Metrics.helveticaBoldCapHeight)
        case .helveticaOblique: return (Base14Metrics.helveticaObliqueWidths, Base14Metrics.helveticaObliqueAscender, Base14Metrics.helveticaObliqueDescender, Base14Metrics.helveticaObliqueCapHeight)
        case .helveticaBoldOblique: return (Base14Metrics.helveticaBoldObliqueWidths, Base14Metrics.helveticaBoldObliqueAscender, Base14Metrics.helveticaBoldObliqueDescender, Base14Metrics.helveticaBoldObliqueCapHeight)
        case .timesRoman: return (Base14Metrics.timesRomanWidths, Base14Metrics.timesRomanAscender, Base14Metrics.timesRomanDescender, Base14Metrics.timesRomanCapHeight)
        case .timesBold: return (Base14Metrics.timesBoldWidths, Base14Metrics.timesBoldAscender, Base14Metrics.timesBoldDescender, Base14Metrics.timesBoldCapHeight)
        case .timesItalic: return (Base14Metrics.timesItalicWidths, Base14Metrics.timesItalicAscender, Base14Metrics.timesItalicDescender, Base14Metrics.timesItalicCapHeight)
        case .timesBoldItalic: return (Base14Metrics.timesBoldItalicWidths, Base14Metrics.timesBoldItalicAscender, Base14Metrics.timesBoldItalicDescender, Base14Metrics.timesBoldItalicCapHeight)
        case .courier: return (Base14Metrics.courierWidths, Base14Metrics.courierAscender, Base14Metrics.courierDescender, Base14Metrics.courierCapHeight)
        case .courierBold: return (Base14Metrics.courierBoldWidths, Base14Metrics.courierBoldAscender, Base14Metrics.courierBoldDescender, Base14Metrics.courierBoldCapHeight)
        case .courierOblique: return (Base14Metrics.courierObliqueWidths, Base14Metrics.courierObliqueAscender, Base14Metrics.courierObliqueDescender, Base14Metrics.courierObliqueCapHeight)
        case .courierBoldOblique: return (Base14Metrics.courierBoldObliqueWidths, Base14Metrics.courierBoldObliqueAscender, Base14Metrics.courierBoldObliqueDescender, Base14Metrics.courierBoldObliqueCapHeight)
        case .symbol: return (Base14Metrics.symbolWidths, Base14Metrics.symbolAscender, Base14Metrics.symbolDescender, Base14Metrics.symbolCapHeight)
        case .zapfDingbats: return (Base14Metrics.zapfDingbatsWidths, Base14Metrics.zapfDingbatsAscender, Base14Metrics.zapfDingbatsDescender, Base14Metrics.zapfDingbatsCapHeight)
        }
    }

    /// Ascender height in 1000-unit em space.
    public var ascender: Int { table.ascender }
    /// Descender depth (negative) in 1000-unit em space.
    public var descender: Int { table.descender }
    /// Capital height in 1000-unit em space.
    public var capHeight: Int { table.capHeight }

    /// Advance width of a character (1000-unit em) for this font's encoding.
    /// Latin fonts index printable ASCII (0x20…0x7E == WinAnsi over that range);
    /// symbolic fonts index the font-specific code directly.
    func advanceWidth(forCode code: Int) -> Int {
        let widths = table.widths
        if isSymbolic {
            return (code >= 0 && code < widths.count) ? widths[code] : Base14Metrics.missingWidth
        }
        guard code >= 0x20, code <= 0x7E else { return Base14Metrics.missingWidth }
        return widths[code - 0x20]
    }

    /// The `/Font` resource dictionary for this font.
    func fontDictionary() -> PDFObject {
        var pairs: [(String, PDFObject)] = [
            ("Type", .name("Font")),
            ("Subtype", .name("Type1")),
            ("BaseFont", .name(baseName)),
        ]
        if !isSymbolic {
            pairs.append(("Encoding", .name("WinAnsiEncoding")))
        }
        return .dict(pairs)
    }
}
