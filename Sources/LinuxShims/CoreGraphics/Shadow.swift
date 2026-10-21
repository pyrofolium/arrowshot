import CCairo
import Foundation

extension CGContext {
    /// Draws `content` over a Core Animation style drop shadow: the content's alpha blurred with a
    /// Gaussian of standard deviation `radius` (user space), moved by `offset` (user space), in
    /// `color` at `opacity`. Cairo has no blur, so the content is drawn into a same-size bitmap
    /// first and its alpha blurred here.
    public func drawWithShadow(
        offset: CGSize, radius: CGFloat, color: CGColor, opacity: CGFloat, _ content: (CGContext) -> Void
    ) {
        guard let layer = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return content(self) }
        var matrix = cairo_matrix_t()
        cairo_get_matrix(cairo, &matrix)
        cairo_set_matrix(layer.cairo, &matrix)
        content(layer)
        cairo_surface_flush(layer.surface)

        let scale = sqrt(abs(matrix.xx * matrix.yy - matrix.xy * matrix.yx))
        let dx = matrix.xx * offset.width + matrix.xy * offset.height
        let dy = matrix.yx * offset.width + matrix.yy * offset.height
        guard let mask = Self.blurredAlpha(of: layer.surface, sigma: radius * scale) else { return content(self) }
        cairo_save(cairo)
        cairo_identity_matrix(cairo)
        cairo_set_source_rgba(cairo, color.red, color.green, color.blue, color.alpha * opacity * state.alpha)
        cairo_mask_surface(cairo, mask, dx, dy)
        cairo_set_source_surface(cairo, layer.surface, 0, 0)
        cairo_paint_with_alpha(cairo, state.alpha)
        cairo_restore(cairo)
        cairo_surface_destroy(mask)
    }

    /// An A8 surface with the ARGB32 surface's alpha blurred: three box blurs each way, the usual
    /// close approximation of a Gaussian.
    static func blurredAlpha(of surface: OpaquePointer, sigma: CGFloat) -> OpaquePointer? {
        let width = Int(cairo_image_surface_get_width(surface))
        let height = Int(cairo_image_surface_get_height(surface))
        let stride = Int(cairo_image_surface_get_stride(surface))
        guard let data = cairo_image_surface_get_data(surface) else { return nil }
        var alpha = [Float](repeating: 0, count: width * height)
        // ARGB32 is native-endian; on little-endian machines alpha is the fourth byte.
        let alphaByte = 1.littleEndian == 1 ? 3 : 0
        for y in 0..<height {
            for x in 0..<width {
                alpha[y * width + x] = Float(data[y * stride + x * 4 + alphaByte])
            }
        }
        if sigma >= 0.5 {
            for box in boxSizes(sigma: Double(sigma), passes: 3) {
                let r = (box - 1) / 2
                blurRows(&alpha, width: width, height: height, radius: r)
                blurColumns(&alpha, width: width, height: height, radius: r)
            }
        }
        guard let mask = cairo_image_surface_create(CAIRO_FORMAT_A8, Int32(width), Int32(height)),
              cairo_surface_status(mask) == CAIRO_STATUS_SUCCESS,
              let out = cairo_image_surface_get_data(mask) else { return nil }
        let maskStride = Int(cairo_image_surface_get_stride(mask))
        for y in 0..<height {
            for x in 0..<width {
                out[y * maskStride + x] = UInt8(max(0, min(255, alpha[y * width + x].rounded())))
            }
        }
        cairo_surface_mark_dirty(mask)
        return mask
    }

    /// Box widths whose repeated blur matches a Gaussian of `sigma` (Kutskir's method).
    static func boxSizes(sigma: Double, passes n: Int) -> [Int] {
        var lower = Int(sqrt(12 * sigma * sigma / Double(n) + 1))
        if lower % 2 == 0 { lower -= 1 }
        let upper = lower + 2
        let ideal = (12 * sigma * sigma - Double(n * lower * lower + 4 * n * lower + 3 * n)) / Double(-4 * lower - 4)
        let m = Int(ideal.rounded())
        return (0..<n).map { $0 < m ? lower : upper }
    }

    /// Mean over a 2r+1 window, transparent outside the image.
    static func blurRows(_ values: inout [Float], width: Int, height: Int, radius r: Int) {
        guard r > 0 else { return }
        var prefix = [Double](repeating: 0, count: width + 1)
        let window = Double(2 * r + 1)
        for y in 0..<height {
            let row = y * width
            for x in 0..<width { prefix[x + 1] = prefix[x] + Double(values[row + x]) }
            for x in 0..<width {
                values[row + x] = Float((prefix[min(width, x + r + 1)] - prefix[max(0, x - r)]) / window)
            }
        }
    }

    static func blurColumns(_ values: inout [Float], width: Int, height: Int, radius r: Int) {
        guard r > 0 else { return }
        var prefix = [Double](repeating: 0, count: height + 1)
        let window = Double(2 * r + 1)
        for x in 0..<width {
            for y in 0..<height { prefix[y + 1] = prefix[y] + Double(values[y * width + x]) }
            for y in 0..<height {
                values[y * width + x] = Float((prefix[min(height, y + r + 1)] - prefix[max(0, y - r)]) / window)
            }
        }
    }
}
