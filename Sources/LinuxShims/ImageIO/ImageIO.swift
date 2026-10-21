@_exported import CoreGraphics
import CCairo
import Foundation

// The ImageIO calls arrowshot makes, for Linux builds: PNG only, read and written with Cairo,
// with the DPI kept in the PNG's pHYs chunk as ImageIO does, so a second pass keeps the scale.

public let kCGImagePropertyDPIWidth: CFString = "DPIWidth"
public let kCGImagePropertyDPIHeight: CFString = "DPIHeight"
public let kCGImagePropertyPixelWidth: CFString = "PixelWidth"
public let kCGImagePropertyPixelHeight: CFString = "PixelHeight"

public final class CGImageSource {
    let url: URL
    let data: Data

    init(url: URL, data: Data) {
        (self.url, self.data) = (url, data)
    }
}

public func CGImageSourceCreateWithURL(_ url: CFURL, _ options: CFDictionary?) -> CGImageSource? {
    guard let data = try? Data(contentsOf: url), data.starts(with: PNG.signature) else { return nil }
    return CGImageSource(url: url, data: data)
}

public func CGImageSourceCreateImageAtIndex(_ source: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CGImage? {
    guard index == 0, let surface = cairo_image_surface_create_from_png(source.url.path) else { return nil }
    defer { cairo_surface_destroy(surface) }
    guard cairo_surface_status(surface) == CAIRO_STATUS_SUCCESS else { return nil }
    return CGImage.copying(surface)
}

public func CGImageSourceCopyPropertiesAtIndex(_ source: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CFDictionary? {
    guard index == 0, let size = PNG.size(source.data) else { return nil }
    var properties: CFDictionary = [kCGImagePropertyPixelWidth: size.width, kCGImagePropertyPixelHeight: size.height]
    if let dpi = PNG.dpi(source.data) {
        properties[kCGImagePropertyDPIWidth] = dpi
        properties[kCGImagePropertyDPIHeight] = dpi
    }
    return properties
}

public final class CGImageDestination {
    let url: URL
    var image: CGImage?
    var dpi: Double?

    init(url: URL) {
        self.url = url
    }
}

public func CGImageDestinationCreateWithURL(
    _ url: CFURL, _ type: CFString, _ count: Int, _ options: CFDictionary?
) -> CGImageDestination? {
    type == "public.png" && count == 1 ? CGImageDestination(url: url) : nil
}

public func CGImageDestinationAddImage(_ destination: CGImageDestination, _ image: CGImage, _ properties: CFDictionary?) {
    destination.image = image
    destination.dpi = properties?[kCGImagePropertyDPIWidth] as? Double
}

public func CGImageDestinationFinalize(_ destination: CGImageDestination) -> Bool {
    guard let image = destination.image else { return false }
    var png = Data()
    let status = withUnsafeMutablePointer(to: &png) { pointer in
        cairo_surface_write_to_png_stream(image.cairoSurface, { closure, bytes, length in
            closure!.assumingMemoryBound(to: Data.self).pointee.append(bytes!, count: Int(length))
            return CAIRO_STATUS_SUCCESS
        }, pointer)
    }
    guard status == CAIRO_STATUS_SUCCESS else { return false }
    let file = destination.dpi.map { PNG.withDPI(png, $0) } ?? png
    return (try? file.write(to: destination.url, options: .atomic)) != nil
}

/// The PNG details ImageIO's stand-in needs: the size from IHDR, and the pHYs (physical size) chunk.
enum PNG {
    static let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    static let metersPerInch = 0.0254
    /// Signature, then IHDR: length, type, 13 bytes of data, CRC.
    static let ihdrEnd = 8 + 8 + 13 + 4

    static func size(_ data: Data) -> (width: Int, height: Int)? {
        let bytes = [UInt8](data.prefix(ihdrEnd))
        guard bytes.count == ihdrEnd else { return nil }
        return (Int(bigEndian(bytes, 16)), Int(bigEndian(bytes, 20)))
    }

    /// The horizontal DPI from pHYs, when it is given per metre.
    static func dpi(_ data: Data) -> Double? {
        let bytes = [UInt8](data)
        var offset = signature.count
        while offset + 8 <= bytes.count {
            let length = Int(bigEndian(bytes, offset))
            let type = String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self)
            let body = offset + 8
            guard body + length <= bytes.count else { return nil }
            if type == "pHYs", length == 9, bytes[body + 8] == 1 {
                return Double(bigEndian(bytes, body)) * metersPerInch
            }
            if type == "IDAT" || type == "IEND" { return nil }
            offset = body + length + 4
        }
        return nil
    }

    /// The PNG with a pHYs chunk for `dpi` right after IHDR (Cairo writes none).
    static func withDPI(_ data: Data, _ dpi: Double) -> Data {
        guard data.count > ihdrEnd else { return data }
        let perMetre = UInt32((dpi / metersPerInch).rounded())
        var chunk = Data("pHYs".utf8)
        chunk.append(contentsOf: bigEndianBytes(perMetre) + bigEndianBytes(perMetre) + [1])
        let crc = chunk.withUnsafeBytes { UInt32(crc32(0, $0.bindMemory(to: UInt8.self).baseAddress, UInt32($0.count))) }
        var result = data.prefix(ihdrEnd)
        result.append(contentsOf: bigEndianBytes(9))
        result.append(chunk)
        result.append(contentsOf: bigEndianBytes(crc))
        result.append(data.suffix(from: data.startIndex + ihdrEnd))
        return result
    }

    static func bigEndian(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        bytes[offset..<(offset + 4)].reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func bigEndianBytes(_ value: UInt32) -> [UInt8] {
        [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
    }
}
