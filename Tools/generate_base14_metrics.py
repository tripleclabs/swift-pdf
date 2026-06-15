#!/usr/bin/env python3
"""Generate Sources/PDFCore/Base14Metrics.swift from the Core-14 AFM metrics.

Source: the URW base-35 AFMs (Artifex), which are metric-compatible with the
Adobe Core-14 standard fonts — verified against known Adobe widths
(Helvetica space=278, A=667, a=556, W=944). Advance widths are factual font
metrics; this generated table is original work (MIT), not derived from libharu.

For the 12 Latin text fonts we emit a 95-entry width array covering printable
ASCII (0x20..0x7E), which equals WinAnsiEncoding over that range. For Symbol and
ZapfDingbats (font-specific encodings) we emit a 256-entry array indexed by the
AFM character code directly.

Run from the package root:  python3 Tools/generate_base14_metrics.py
"""
import re
import sys
import urllib.request

BASE = "https://raw.githubusercontent.com/ArtifexSoftware/urw-base35-fonts/master/fonts/"

# swift case -> (PostScript BaseFont name, URW AFM file, is_symbolic)
FONTS = [
    ("helvetica",            "Helvetica",             "NimbusSans-Regular.afm",      False),
    ("helveticaBold",        "Helvetica-Bold",        "NimbusSans-Bold.afm",         False),
    ("helveticaOblique",     "Helvetica-Oblique",     "NimbusSans-Italic.afm",       False),
    ("helveticaBoldOblique", "Helvetica-BoldOblique", "NimbusSans-BoldItalic.afm",   False),
    ("timesRoman",           "Times-Roman",           "NimbusRoman-Regular.afm",     False),
    ("timesBold",            "Times-Bold",            "NimbusRoman-Bold.afm",         False),
    ("timesItalic",          "Times-Italic",          "NimbusRoman-Italic.afm",      False),
    ("timesBoldItalic",      "Times-BoldItalic",      "NimbusRoman-BoldItalic.afm",  False),
    ("courier",              "Courier",               "NimbusMonoPS-Regular.afm",    False),
    ("courierBold",          "Courier-Bold",          "NimbusMonoPS-Bold.afm",       False),
    ("courierOblique",       "Courier-Oblique",       "NimbusMonoPS-Italic.afm",     False),
    ("courierBoldOblique",   "Courier-BoldOblique",   "NimbusMonoPS-BoldItalic.afm", False),
    ("symbol",               "Symbol",                "StandardSymbolsPS.afm",       True),
    ("zapfDingbats",         "ZapfDingbats",          "D050000L.afm",                True),
]

# Printable ASCII (0x20..0x7E) glyph names — standard AGL names; equals
# WinAnsiEncoding over this range.
ASCII_NAMES = {
    0x20: "space", 0x21: "exclam", 0x22: "quotedbl", 0x23: "numbersign",
    0x24: "dollar", 0x25: "percent", 0x26: "ampersand", 0x27: "quotesingle",
    0x28: "parenleft", 0x29: "parenright", 0x2A: "asterisk", 0x2B: "plus",
    0x2C: "comma", 0x2D: "hyphen", 0x2E: "period", 0x2F: "slash",
    0x30: "zero", 0x31: "one", 0x32: "two", 0x33: "three", 0x34: "four",
    0x35: "five", 0x36: "six", 0x37: "seven", 0x38: "eight", 0x39: "nine",
    0x3A: "colon", 0x3B: "semicolon", 0x3C: "less", 0x3D: "equal",
    0x3E: "greater", 0x3F: "question", 0x40: "at",
    0x5B: "bracketleft", 0x5C: "backslash", 0x5D: "bracketright",
    0x5E: "asciicircum", 0x5F: "underscore", 0x60: "grave",
    0x7B: "braceleft", 0x7C: "bar", 0x7D: "braceright", 0x7E: "asciitilde",
}
for c in range(0x41, 0x5B):  # A..Z
    ASCII_NAMES[c] = chr(c)
for c in range(0x61, 0x7B):  # a..z
    ASCII_NAMES[c] = chr(c)

# WinAnsiEncoding (cp1252) high range 0x80..0xFF — covers Latin-1 (German,
# French, Spanish, etc.) plus the cp1252 punctuation block (PDF spec Annex D).
ASCII_NAMES.update({
    0x80: "Euro", 0x82: "quotesinglbase", 0x83: "florin", 0x84: "quotedblbase",
    0x85: "ellipsis", 0x86: "dagger", 0x87: "daggerdbl", 0x88: "circumflex",
    0x89: "perthousand", 0x8A: "Scaron", 0x8B: "guilsinglleft", 0x8C: "OE",
    0x8E: "Zcaron", 0x91: "quoteleft", 0x92: "quoteright", 0x93: "quotedblleft",
    0x94: "quotedblright", 0x95: "bullet", 0x96: "endash", 0x97: "emdash",
    0x98: "tilde", 0x99: "trademark", 0x9A: "scaron", 0x9B: "guilsinglright",
    0x9C: "oe", 0x9E: "zcaron", 0x9F: "Ydieresis",
    0xA0: "space", 0xA1: "exclamdown", 0xA2: "cent", 0xA3: "sterling",
    0xA4: "currency", 0xA5: "yen", 0xA6: "brokenbar", 0xA7: "section",
    0xA8: "dieresis", 0xA9: "copyright", 0xAA: "ordfeminine", 0xAB: "guillemotleft",
    0xAC: "logicalnot", 0xAD: "hyphen", 0xAE: "registered", 0xAF: "macron",
    0xB0: "degree", 0xB1: "plusminus", 0xB2: "twosuperior", 0xB3: "threesuperior",
    0xB4: "acute", 0xB5: "mu", 0xB6: "paragraph", 0xB7: "periodcentered",
    0xB8: "cedilla", 0xB9: "onesuperior", 0xBA: "ordmasculine", 0xBB: "guillemotright",
    0xBC: "onequarter", 0xBD: "onehalf", 0xBE: "threequarters", 0xBF: "questiondown",
    0xC0: "Agrave", 0xC1: "Aacute", 0xC2: "Acircumflex", 0xC3: "Atilde",
    0xC4: "Adieresis", 0xC5: "Aring", 0xC6: "AE", 0xC7: "Ccedilla",
    0xC8: "Egrave", 0xC9: "Eacute", 0xCA: "Ecircumflex", 0xCB: "Edieresis",
    0xCC: "Igrave", 0xCD: "Iacute", 0xCE: "Icircumflex", 0xCF: "Idieresis",
    0xD0: "Eth", 0xD1: "Ntilde", 0xD2: "Ograve", 0xD3: "Oacute",
    0xD4: "Ocircumflex", 0xD5: "Otilde", 0xD6: "Odieresis", 0xD7: "multiply",
    0xD8: "Oslash", 0xD9: "Ugrave", 0xDA: "Uacute", 0xDB: "Ucircumflex",
    0xDC: "Udieresis", 0xDD: "Yacute", 0xDE: "Thorn", 0xDF: "germandbls",
    0xE0: "agrave", 0xE1: "aacute", 0xE2: "acircumflex", 0xE3: "atilde",
    0xE4: "adieresis", 0xE5: "aring", 0xE6: "ae", 0xE7: "ccedilla",
    0xE8: "egrave", 0xE9: "eacute", 0xEA: "ecircumflex", 0xEB: "edieresis",
    0xEC: "igrave", 0xED: "iacute", 0xEE: "icircumflex", 0xEF: "idieresis",
    0xF0: "eth", 0xF1: "ntilde", 0xF2: "ograve", 0xF3: "oacute",
    0xF4: "ocircumflex", 0xF5: "otilde", 0xF6: "odieresis", 0xF7: "divide",
    0xF8: "oslash", 0xF9: "ugrave", 0xFA: "uacute", 0xFB: "ucircumflex",
    0xFC: "udieresis", 0xFD: "yacute", 0xFE: "thorn", 0xFF: "ydieresis",
})


def parse_afm(text):
    """Return (name->wx, code->wx, metrics dict)."""
    name_wx, code_wx, metrics = {}, {}, {}
    for key in ("Ascender", "Descender", "CapHeight", "XHeight"):
        m = re.search(rf"^{key}\s+(-?\d+)", text, re.M)
        if m:
            metrics[key] = int(m.group(1))
    m = re.search(r"^FontBBox\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)", text, re.M)
    if m:
        metrics["FontBBox"] = [int(g) for g in m.groups()]
    for line in text.splitlines():
        if not line.startswith("C "):
            continue
        cm = re.search(r"C\s+(-?\d+)\s*;", line)
        wm = re.search(r"WX\s+(-?\d+)\s*;", line)
        nm = re.search(r"N\s+(\S+)\s*;", line)
        if not (cm and wm and nm):
            continue
        code, wx, name = int(cm.group(1)), int(wm.group(1)), nm.group(1)
        name_wx[name] = wx
        if 0 <= code <= 255:
            code_wx[code] = wx
    return name_wx, code_wx, metrics


def swift_int_array(values):
    rows = []
    for i in range(0, len(values), 16):
        rows.append("        " + ", ".join(str(v) for v in values[i:i + 16]) + ",")
    return "\n".join(rows)


def main():
    out = []
    out.append("// Copyright (c) 2026 Triple C Labs GmbH.")
    out.append("// SPDX-License-Identifier: MIT")
    out.append("//")
    out.append("// GENERATED by Tools/generate_base14_metrics.py — do not edit by hand.")
    out.append("// Advance widths (per 1000-unit em) for the 14 standard fonts, transcribed")
    out.append("// from the URW base-35 AFM metrics (metric-compatible with Adobe Core-14).")
    out.append("// Factual font metrics; original work, not derived from libharu.")
    out.append("")
    out.append("enum Base14Metrics {")
    out.append("    /// Width of a glyph not present in a font's table.")
    out.append("    static let missingWidth = 0")
    out.append("")

    for swift_name, _ps, afm_file, symbolic in FONTS:
        text = urllib.request.urlopen(BASE + afm_file, timeout=30).read().decode("latin1")
        name_wx, code_wx, metrics = parse_afm(text)

        if symbolic:
            widths = [code_wx.get(c, 0) for c in range(256)]
            comment = "256 entries indexed by font-specific character code"
        else:
            widths = []
            for c in range(0x20, 0x100):
                gname = ASCII_NAMES.get(c)
                w = name_wx.get(gname, 0) if gname else 0
                widths.append(w)
            comment = "224 entries for WinAnsiEncoding codes 0x20..0xFF"

        asc = metrics.get("Ascender", 0)
        desc = metrics.get("Descender", 0)
        cap = metrics.get("CapHeight", 0)
        out.append(f"    /// {_ps} — {comment}.")
        out.append(f"    static let {swift_name}Widths: [Int] = [")
        out.append(swift_int_array(widths))
        out.append("    ]")
        out.append(f"    static let {swift_name}Ascender = {asc}")
        out.append(f"    static let {swift_name}Descender = {desc}")
        out.append(f"    static let {swift_name}CapHeight = {cap}")
        out.append("")

    out.append("}")
    with open("Sources/PDFCore/Base14Metrics.swift", "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"wrote Sources/PDFCore/Base14Metrics.swift ({len(FONTS)} fonts)")


if __name__ == "__main__":
    main()
