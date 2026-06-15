// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

/// A decoded (or DCT-encoded) image ready to embed as a PDF image XObject.
/// Produced outside PDFCore (e.g. by the libpng-backed decoder) so the core
/// stays dependency-free; PDFCore only assembles the XObject from these fields.
public struct PDFImageData: Sendable {
    public enum ColorSpace: String, Sendable {
        case deviceRGB = "DeviceRGB"
        case deviceGray = "DeviceGray"
        case deviceCMYK = "DeviceCMYK"
    }

    /// An 8-bit grayscale soft mask (alpha channel), embedded as `/SMask`.
    public struct SoftMask: Sendable {
        public var width: Int
        public var height: Int
        public var data: [UInt8]
        public init(width: Int, height: Int, data: [UInt8]) {
            self.width = width; self.height = height; self.data = data
        }
    }

    public var width: Int
    public var height: Int
    public var bitsPerComponent: Int
    public var colorSpace: ColorSpace
    /// Sample bytes (raw) or encoded bytes (when `filter` is set, e.g. JPEG).
    public var data: [UInt8]
    /// A pre-applied filter such as `DCTDecode` (JPEG), or `nil` for raw samples
    /// that the document may compress with FlateDecode.
    public var filter: String?
    public var softMask: SoftMask?
    /// Stable identity for per-document XObject deduplication.
    public let key: String

    public init(width: Int, height: Int, bitsPerComponent: Int, colorSpace: ColorSpace,
                data: [UInt8], filter: String? = nil, softMask: SoftMask? = nil) {
        self.width = width
        self.height = height
        self.bitsPerComponent = bitsPerComponent
        self.colorSpace = colorSpace
        self.data = data
        self.filter = filter
        self.softMask = softMask
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in [UInt8("I".utf8.first!)] + data.prefix(64) { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        self.key = "img:\(width)x\(height):\(data.count):\(hash)"
    }
}
