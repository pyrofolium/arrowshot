import CCairo
import Foundation

public enum CGLineCap: Int32, Sendable { case butt, round, square }
public enum CGLineJoin: Int32, Sendable { case miter, round, bevel }
public enum CGPathDrawingMode: Int32, Sendable { case fill, eoFill, stroke, fillStroke, eoFillStroke }
public enum CGInterpolationQuality: Int32, Sendable { case `default`, none, low, medium, high }

/// A CoreGraphics bitmap context on a Cairo image surface. Like CoreGraphics it starts y-up with
/// the origin at the bottom-left; images it makes have their first row at the top.
public final class CGContext {
    /// The `cairo_t`, for Linux code (Pango text) that draws with Cairo directly.
    public let cairo: OpaquePointer
    let surface: OpaquePointer
    public let width: Int
    public let height: Int

    struct State {
        var fill = CGColor.black
        var stroke = CGColor.black
        var lineWidth: CGFloat = 1
        var cap = CGLineCap.butt
        var join = CGLineJoin.miter
        var alpha: CGFloat = 1
    }

    var state = State()
    var saved: [State] = []
    public var interpolationQuality = CGInterpolationQuality.default

    /// Always 8-bit premultiplied; with `data`, the caller's memory holds the pixels in Cairo's
    /// native ARGB32 order (BGRA bytes on little-endian machines), not CoreGraphics' RGBA.
    public init?(
        data: UnsafeMutableRawPointer?, width: Int, height: Int, bitsPerComponent: Int, bytesPerRow: Int,
        space: CGColorSpace, bitmapInfo: UInt32
    ) {
        guard bitsPerComponent == 8, width > 0, height > 0 else { return nil }
        let created: OpaquePointer?
        if let data {
            let stride = cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, Int32(width))
            guard bytesPerRow == Int(stride) else { return nil }
            created = cairo_image_surface_create_for_data(
                data.assumingMemoryBound(to: UInt8.self), CAIRO_FORMAT_ARGB32, Int32(width), Int32(height), stride
            )
        } else {
            created = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, Int32(width), Int32(height))
        }
        guard let surface = created, cairo_surface_status(surface) == CAIRO_STATUS_SUCCESS else { return nil }
        self.surface = surface
        cairo = cairo_create(surface)
        self.width = width
        self.height = height
        cairo_translate(cairo, 0, CGFloat(height))
        cairo_scale(cairo, 1, -1)
    }

    deinit {
        cairo_destroy(cairo)
        cairo_surface_flush(surface)
        cairo_surface_destroy(surface)
    }

    // MARK: State

    public func saveGState() {
        cairo_save(cairo)
        saved.append(state)
    }

    public func restoreGState() {
        cairo_restore(cairo)
        if let last = saved.popLast() { state = last }
    }

    public func scaleBy(x: CGFloat, y: CGFloat) { cairo_scale(cairo, x, y) }
    public func translateBy(x: CGFloat, y: CGFloat) { cairo_translate(cairo, x, y) }
    public func rotate(by angle: CGFloat) { cairo_rotate(cairo, angle) }

    public func concatenate(_ t: CGAffineTransform) {
        var matrix = cairo_matrix_t(xx: t.a, yx: t.b, xy: t.c, yy: t.d, x0: t.tx, y0: t.ty)
        cairo_transform(cairo, &matrix)
    }

    /// User space to device pixels, top-left origin.
    public var ctm: CGAffineTransform {
        var m = cairo_matrix_t()
        cairo_get_matrix(cairo, &m)
        return CGAffineTransform(a: m.xx, b: m.yx, c: m.xy, d: m.yy, tx: m.x0, ty: m.y0)
    }

    public func setFillColor(_ color: CGColor) { state.fill = color }
    public func setStrokeColor(_ color: CGColor) { state.stroke = color }
    public func setLineWidth(_ width: CGFloat) { state.lineWidth = width }
    public func setLineCap(_ cap: CGLineCap) { state.cap = cap }
    public func setLineJoin(_ join: CGLineJoin) { state.join = join }
    public func setAlpha(_ alpha: CGFloat) { state.alpha = alpha }

    public func setShouldAntialias(_ antialias: Bool) {
        cairo_set_antialias(cairo, antialias ? CAIRO_ANTIALIAS_DEFAULT : CAIRO_ANTIALIAS_NONE)
    }

    // MARK: Paths

    public func beginPath() { cairo_new_path(cairo) }

    public func addPath(_ path: CGPath) {
        replay(path.segments, into: cairo)
    }

    public func move(to point: CGPoint) { cairo_move_to(cairo, point.x, point.y) }
    public func addLine(to point: CGPoint) { cairo_line_to(cairo, point.x, point.y) }
    public func closePath() { cairo_close_path(cairo) }

    public func addRect(_ rect: CGRect) {
        cairo_rectangle(cairo, rect.minX, rect.minY, rect.width, rect.height)
    }

    public func addEllipse(in rect: CGRect) {
        addPath(CGPath(ellipseIn: rect, transform: nil))
    }

    public func addLines(between points: [CGPoint]) {
        let path = CGMutablePath()
        path.addLines(between: points)
        addPath(path)
    }

    // MARK: Painting

    private func source(_ color: CGColor) {
        cairo_set_source_rgba(cairo, color.red, color.green, color.blue, color.alpha * state.alpha)
    }

    private func applyStroke() {
        source(state.stroke)
        cairo_set_line_width(cairo, state.lineWidth)
        cairo_set_line_cap(cairo, cairo_line_cap_t(rawValue: UInt32(state.cap.rawValue)))
        cairo_set_line_join(cairo, cairo_line_join_t(rawValue: UInt32(state.join.rawValue)))
    }

    public func fillPath(using rule: CGPathFillRule = .winding) {
        cairo_set_fill_rule(cairo, rule == .evenOdd ? CAIRO_FILL_RULE_EVEN_ODD : CAIRO_FILL_RULE_WINDING)
        source(state.fill)
        cairo_fill(cairo)
    }

    public func eoFillPath() { fillPath(using: .evenOdd) }

    public func strokePath() {
        applyStroke()
        cairo_stroke(cairo)
    }

    public func drawPath(using mode: CGPathDrawingMode) {
        let evenOdd = mode == .eoFill || mode == .eoFillStroke
        cairo_set_fill_rule(cairo, evenOdd ? CAIRO_FILL_RULE_EVEN_ODD : CAIRO_FILL_RULE_WINDING)
        switch mode {
        case .fill, .eoFill:
            source(state.fill)
            cairo_fill(cairo)
        case .stroke:
            strokePath()
        case .fillStroke, .eoFillStroke:
            source(state.fill)
            cairo_fill_preserve(cairo)
            strokePath()
        }
    }

    public func fill(_ rect: CGRect) {
        beginPath()
        addRect(rect)
        fillPath()
    }

    public func fill(_ rects: [CGRect]) {
        beginPath()
        rects.forEach(addRect)
        fillPath()
    }

    public func fillEllipse(in rect: CGRect) {
        beginPath()
        addEllipse(in: rect)
        fillPath()
    }

    public func stroke(_ rect: CGRect) {
        beginPath()
        addRect(rect)
        strokePath()
    }

    public func strokeEllipse(in rect: CGRect) {
        beginPath()
        addEllipse(in: rect)
        strokePath()
    }

    /// Strokes each pair of points as its own segment.
    public func strokeLineSegments(between points: [CGPoint]) {
        beginPath()
        var index = 0
        while index + 1 < points.count {
            move(to: points[index])
            addLine(to: points[index + 1])
            index += 2
        }
        strokePath()
    }

    public func clear(_ rect: CGRect) {
        cairo_save(cairo)
        cairo_set_operator(cairo, CAIRO_OPERATOR_CLEAR)
        cairo_rectangle(cairo, rect.minX, rect.minY, rect.width, rect.height)
        cairo_fill(cairo)
        cairo_restore(cairo)
    }

    public func clip() { cairo_clip(cairo) }

    public func clip(to rect: CGRect) {
        beginPath()
        addRect(rect)
        cairo_clip(cairo)
    }

    /// Draws the image upright into `rect`, as CoreGraphics does in a y-up context.
    public func draw(_ image: CGImage, in rect: CGRect) {
        guard image.width > 0, image.height > 0, rect.width > 0, rect.height > 0 else { return }
        cairo_save(cairo)
        cairo_translate(cairo, rect.minX, rect.maxY)
        cairo_scale(cairo, rect.width / CGFloat(image.width), -rect.height / CGFloat(image.height))
        cairo_set_source_surface(cairo, image.cairoSurface, 0, 0)
        let filter = interpolationQuality == .none ? CAIRO_FILTER_NEAREST : CAIRO_FILTER_GOOD
        cairo_pattern_set_filter(cairo_get_source(cairo), filter)
        cairo_paint_with_alpha(cairo, state.alpha)
        cairo_restore(cairo)
    }

    public func makeImage() -> CGImage? {
        CGImage.copying(surface)
    }
}
