import CCairo
import Foundation

public struct CGImageAlphaInfo: RawRepresentable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let none = CGImageAlphaInfo(rawValue: 0)
    public static let premultipliedLast = CGImageAlphaInfo(rawValue: 1)
    public static let premultipliedFirst = CGImageAlphaInfo(rawValue: 2)
    public static let last = CGImageAlphaInfo(rawValue: 3)
    public static let first = CGImageAlphaInfo(rawValue: 4)
    public static let noneSkipLast = CGImageAlphaInfo(rawValue: 5)
    public static let noneSkipFirst = CGImageAlphaInfo(rawValue: 6)
}

/// An immutable bitmap: a Cairo ARGB32 (premultiplied) image surface this image owns.
public final class CGImage: @unchecked Sendable {
    /// The `cairo_surface_t`, for Linux code that hands it to Cairo directly.
    public let cairoSurface: OpaquePointer

    /// Takes ownership of an image surface.
    public init(cairoSurface: OpaquePointer) {
        self.cairoSurface = cairoSurface
    }

    deinit {
        cairo_surface_destroy(cairoSurface)
    }

    public var width: Int { Int(cairo_image_surface_get_width(cairoSurface)) }
    public var height: Int { Int(cairo_image_surface_get_height(cairoSurface)) }
    public var bitsPerComponent: Int { 8 }
    public var bitsPerPixel: Int { 32 }
    public var bytesPerRow: Int { Int(cairo_image_surface_get_stride(cairoSurface)) }

    /// A copy of an image surface, so later drawing into the source never changes this image.
    public static func copying(_ surface: OpaquePointer) -> CGImage? {
        cairo_surface_flush(surface)
        let width = cairo_image_surface_get_width(surface)
        let height = cairo_image_surface_get_height(surface)
        guard let copy = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height),
              cairo_surface_status(copy) == CAIRO_STATUS_SUCCESS else { return nil }
        let cr = cairo_create(copy)
        cairo_set_source_surface(cr, surface, 0, 0)
        cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
        cairo_paint(cr)
        cairo_destroy(cr)
        cairo_surface_flush(copy)
        return CGImage(cairoSurface: copy)
    }
}
