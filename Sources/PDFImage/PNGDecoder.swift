// Copyright (c) 2026 Triple C Labs GmbH.
// SPDX-License-Identifier: MIT

import CLibPNG
import Foundation
import PDFCore

public enum ImageError: Error { case decodeFailed }

public enum PDFImageLoader {

    /// Decode a PNG into an embeddable image using libpng's simplified read API.
    /// The image is read as RGBA8 and split into a DeviceRGB image plus, when
    /// any pixel is non-opaque, an 8-bit `/SMask` (alpha channel).
    public static func png(_ data: Data) throws -> PDFImageData {
        var image = png_image()
        image.version = png_uint_32(PNG_IMAGE_VERSION)

        let began = data.withUnsafeBytes { raw in
            png_image_begin_read_from_memory(&image, raw.baseAddress, raw.count)
        }
        guard began != 0 else { png_image_free(&image); throw ImageError.decodeFailed }

        // PNG_FORMAT_RGBA is a compound macro Swift can't import:
        // PNG_FORMAT_FLAG_COLOR (0x02) | PNG_FORMAT_FLAG_ALPHA (0x01).
        image.format = png_uint_32(0x03)
        let width = Int(image.width), height = Int(image.height)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let read = rgba.withUnsafeMutableBytes { buf in
            png_image_finish_read(&image, nil, buf.baseAddress, 0, nil)
        }
        guard read != 0 else { png_image_free(&image); throw ImageError.decodeFailed }

        var rgb = [UInt8](); rgb.reserveCapacity(width * height * 3)
        var alpha = [UInt8](); alpha.reserveCapacity(width * height)
        var hasAlpha = false
        var i = 0
        while i < rgba.count {
            rgb.append(rgba[i]); rgb.append(rgba[i + 1]); rgb.append(rgba[i + 2])
            let a = rgba[i + 3]
            alpha.append(a)
            if a != 255 { hasAlpha = true }
            i += 4
        }

        return PDFImageData(
            width: width, height: height, bitsPerComponent: 8, colorSpace: .deviceRGB,
            data: rgb,
            softMask: hasAlpha ? .init(width: width, height: height, data: alpha) : nil)
    }

    /// Embed a JPEG with no decoding: the bytes are passed through with the PDF
    /// `DCTDecode` filter (the reader decodes them). Width/height/components are
    /// read from the JPEG's SOF marker.
    public static func jpeg(_ data: Data) throws -> PDFImageData {
        let bytes = [UInt8](data)
        guard bytes.count > 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { throw ImageError.decodeFailed }
        var i = 2
        while i + 9 < bytes.count {
            guard bytes[i] == 0xFF else { i += 1; continue }
            let marker = bytes[i + 1]
            // SOF0..SOF15, excluding DHT(C4), JPG(C8), DAC(CC).
            if (0xC0...0xCF).contains(marker), marker != 0xC4, marker != 0xC8, marker != 0xCC {
                let height = Int(bytes[i + 5]) << 8 | Int(bytes[i + 6])
                let width = Int(bytes[i + 7]) << 8 | Int(bytes[i + 8])
                let components = Int(bytes[i + 9])
                let cs: PDFImageData.ColorSpace = components == 1 ? .deviceGray
                    : (components == 4 ? .deviceCMYK : .deviceRGB)
                guard width > 0, height > 0 else { throw ImageError.decodeFailed }
                return PDFImageData(width: width, height: height, bitsPerComponent: 8,
                                    colorSpace: cs, data: bytes, filter: "DCTDecode")
            }
            if marker == 0xD8 || marker == 0xD9 || (0xD0...0xD7).contains(marker) {
                i += 2   // standalone markers (no length)
            } else {
                let len = Int(bytes[i + 2]) << 8 | Int(bytes[i + 3])
                i += 2 + len
            }
        }
        throw ImageError.decodeFailed
    }
}
