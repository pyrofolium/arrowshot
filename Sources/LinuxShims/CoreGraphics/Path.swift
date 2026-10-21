import CCairo
import Foundation

public enum CGPathElementType: Int32, Sendable {
    case moveToPoint, addLineToPoint, addQuadCurveToPoint, addCurveToPoint, closeSubpath
}

public enum CGPathFillRule: Int, Sendable {
    case winding, evenOdd
}

/// One stored segment; arcs, ellipses and rounded corners are kept as cubic Béziers.
enum PathSegment: Equatable {
    case move(CGPoint)
    case line(CGPoint)
    case quad(CGPoint, CGPoint)
    case curve(CGPoint, CGPoint, CGPoint)
    case close

    func applying(_ t: CGAffineTransform) -> PathSegment {
        switch self {
        case .move(let p): .move(p.applying(t))
        case .line(let p): .line(p.applying(t))
        case .quad(let c, let p): .quad(c.applying(t), p.applying(t))
        case .curve(let c1, let c2, let p): .curve(c1.applying(t), c2.applying(t), p.applying(t))
        case .close: .close
        }
    }

    var points: [CGPoint] {
        switch self {
        case .move(let p), .line(let p): [p]
        case .quad(let c, let p): [c, p]
        case .curve(let c1, let c2, let p): [c1, c2, p]
        case .close: []
        }
    }
}

/// CoreGraphics' immutable path for Linux builds: the segments arrowshot draws with.
open class CGPath: @unchecked Sendable, Equatable {
    var segments: [PathSegment]

    init(segments: [PathSegment]) {
        self.segments = segments
    }

    public convenience init(rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {
        let path = CGMutablePath()
        path.addRect(rect, transform: transform?.pointee ?? .identity)
        self.init(segments: path.segments)
    }

    public convenience init(
        roundedRect rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat, transform: UnsafePointer<CGAffineTransform>?
    ) {
        let path = CGMutablePath()
        path.addRoundedRect(in: rect, cornerWidth: cornerWidth, cornerHeight: cornerHeight, transform: transform?.pointee ?? .identity)
        self.init(segments: path.segments)
    }

    public convenience init(ellipseIn rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {
        let path = CGMutablePath()
        path.addEllipse(in: rect, transform: transform?.pointee ?? .identity)
        self.init(segments: path.segments)
    }

    public static func == (lhs: CGPath, rhs: CGPath) -> Bool {
        lhs.segments == rhs.segments
    }

    public var isEmpty: Bool { segments.isEmpty }

    /// The box around every point, control points included, as Apple documents it.
    open var boundingBox: CGRect {
        let points = segments.flatMap(\.points)
        guard let first = points.first else { return .null }
        var (minX, minY, maxX, maxY) = (first.x, first.y, first.x, first.y)
        for p in points {
            (minX, minY, maxX, maxY) = (min(minX, p.x), min(minY, p.y), max(maxX, p.x), max(maxY, p.y))
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public var boundingBoxOfPath: CGRect { boundingBox }

    public var currentPoint: CGPoint {
        Self.currentPoint(of: segments) ?? .zero
    }

    static func currentPoint(of segments: [PathSegment]) -> CGPoint? {
        guard let last = segments.last else { return nil }
        if case .close = last { return subpathStart(of: segments) }
        return last.points.last
    }

    static func subpathStart(of segments: [PathSegment]) -> CGPoint? {
        for segment in segments.reversed() {
            if case .move(let p) = segment { return p }
        }
        return nil
    }

    public func copy() -> CGPath {
        CGPath(segments: segments)
    }

    public func copy(using transform: UnsafePointer<CGAffineTransform>?) -> CGPath? {
        let t = transform?.pointee ?? .identity
        return CGPath(segments: segments.map { $0.applying(t) })
    }

    /// Whether the fill of the path covers `point`.
    open func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding, transform: CGAffineTransform = .identity) -> Bool {
        HitTest.run { cr in
            cairo_set_fill_rule(cr, rule == .evenOdd ? CAIRO_FILL_RULE_EVEN_ODD : CAIRO_FILL_RULE_WINDING)
            replay(segments.map { $0.applying(transform) }, into: cr)
            return cairo_in_fill(cr, point.x, point.y) != 0
        }
    }

    /// The outline of the stroked path. Cairo cannot turn a stroke into a path, so the copy keeps
    /// the stroke and answers `contains` and `boundingBox` for it; it is not for drawing.
    public func copy(
        strokingWithWidth lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat,
        transform: CGAffineTransform = .identity
    ) -> CGPath {
        StrokedPath(
            segments: segments.map { $0.applying(transform) }, width: lineWidth, cap: lineCap, join: lineJoin, miterLimit: miterLimit
        )
    }

    public func mutableCopy() -> CGMutablePath? {
        let path = CGMutablePath()
        path.segments = segments
        return path
    }
}

/// A stroke kept as its centre line and pen, for hit-testing (see `copy(strokingWithWidth:)`).
final class StrokedPath: CGPath, @unchecked Sendable {
    let width: CGFloat
    let cap: CGLineCap
    let join: CGLineJoin
    let miterLimit: CGFloat

    init(segments: [PathSegment], width: CGFloat, cap: CGLineCap, join: CGLineJoin, miterLimit: CGFloat) {
        (self.width, self.cap, self.join, self.miterLimit) = (width, cap, join, miterLimit)
        super.init(segments: segments)
    }

    override func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding, transform: CGAffineTransform = .identity) -> Bool {
        HitTest.run { cr in
            replay(segments.map { $0.applying(transform) }, into: cr)
            cairo_set_line_width(cr, width)
            cairo_set_line_cap(cr, cairo_line_cap_t(rawValue: UInt32(cap.rawValue)))
            cairo_set_line_join(cr, cairo_line_join_t(rawValue: UInt32(join.rawValue)))
            cairo_set_miter_limit(cr, miterLimit)
            return cairo_in_stroke(cr, point.x, point.y) != 0
        }
    }

    override var boundingBox: CGRect {
        super.boundingBox.insetBy(dx: -width / 2, dy: -width / 2)
    }
}

/// A throwaway Cairo context for geometric questions; nothing is drawn.
enum HitTest {
    static func run<T>(_ body: (OpaquePointer) -> T) -> T {
        let surface = cairo_image_surface_create(CAIRO_FORMAT_A8, 1, 1)
        let cr = cairo_create(surface)!
        // Flatten curves far finer than Cairo's 0.1 default, so hairline strokes still hit.
        cairo_set_tolerance(cr, 0.0001)
        defer {
            cairo_destroy(cr)
            cairo_surface_destroy(surface)
        }
        return body(cr)
    }
}

/// Adds the segments to a Cairo path, quadratics as the cubics with the same curve.
func replay(_ segments: [PathSegment], into cr: OpaquePointer) {
    var current = CGPoint.zero
    var start = CGPoint.zero
    for segment in segments {
        switch segment {
        case .move(let p):
            cairo_move_to(cr, p.x, p.y)
            (current, start) = (p, p)
        case .line(let p):
            cairo_line_to(cr, p.x, p.y)
            current = p
        case .quad(let c, let p):
            let c1 = CGPoint(x: current.x + 2 / 3 * (c.x - current.x), y: current.y + 2 / 3 * (c.y - current.y))
            let c2 = CGPoint(x: p.x + 2 / 3 * (c.x - p.x), y: p.y + 2 / 3 * (c.y - p.y))
            cairo_curve_to(cr, c1.x, c1.y, c2.x, c2.y, p.x, p.y)
            current = p
        case .curve(let c1, let c2, let p):
            cairo_curve_to(cr, c1.x, c1.y, c2.x, c2.y, p.x, p.y)
            current = p
        case .close:
            cairo_close_path(cr)
            current = start
        }
    }
}

public final class CGMutablePath: CGPath, @unchecked Sendable {
    public init() {
        super.init(segments: [])
    }

    public func move(to point: CGPoint, transform: CGAffineTransform = .identity) {
        segments.append(.move(point.applying(transform)))
    }

    public func addLine(to point: CGPoint, transform: CGAffineTransform = .identity) {
        segments.append(.line(point.applying(transform)))
    }

    public func addLines(between points: [CGPoint], transform: CGAffineTransform = .identity) {
        guard let first = points.first else { return }
        move(to: first, transform: transform)
        for point in points.dropFirst() { addLine(to: point, transform: transform) }
    }

    public func addQuadCurve(to end: CGPoint, control: CGPoint, transform: CGAffineTransform = .identity) {
        segments.append(.quad(control.applying(transform), end.applying(transform)))
    }

    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint, transform: CGAffineTransform = .identity) {
        segments.append(.curve(control1.applying(transform), control2.applying(transform), end.applying(transform)))
    }

    public func closeSubpath() {
        guard !segments.isEmpty else { return }
        segments.append(.close)
    }

    public func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) {
        addLines(between: [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)
        ], transform: transform)
        closeSubpath()
    }

    public func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) {
        for rect in rects { addRect(rect, transform: transform) }
    }

    /// An arc of a circle; with `clockwise` the angle decreases (Apple's y-up convention). Like
    /// CoreGraphics, a line joins the current point to the arc's start.
    public func addArc(
        center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool,
        transform: CGAffineTransform = .identity
    ) {
        var sweep = endAngle - startAngle
        if clockwise {
            while sweep > 0 { sweep -= 2 * .pi }
        } else {
            while sweep < 0 { sweep += 2 * .pi }
        }
        let start = CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        if Self.currentPoint(of: segments) == nil || segments.last == .close {
            move(to: start, transform: transform)
        } else {
            addLine(to: start, transform: transform)
        }
        appendArcPieces(center: center, radius: radius, startAngle: startAngle, sweep: sweep, transform: transform)
    }

    private func appendArcPieces(center: CGPoint, radius: CGFloat, startAngle: CGFloat, sweep: CGFloat, transform: CGAffineTransform) {
        let pieces = max(1, Int((abs(sweep) / (.pi / 2)).rounded(.up)))
        let step = sweep / CGFloat(pieces)
        var angle = startAngle
        for _ in 0..<pieces {
            appendArc(center: center, radius: radius, from: angle, to: angle + step, transform: transform)
            angle += step
        }
    }

    /// One arc piece of at most a quarter turn as a cubic Bézier.
    private func appendArc(center: CGPoint, radius: CGFloat, from a0: CGFloat, to a1: CGFloat, transform: CGAffineTransform) {
        let k = 4 / 3 * tan((a1 - a0) / 4)
        let p0 = CGPoint(x: center.x + radius * cos(a0), y: center.y + radius * sin(a0))
        let p3 = CGPoint(x: center.x + radius * cos(a1), y: center.y + radius * sin(a1))
        let c1 = CGPoint(x: p0.x - k * radius * sin(a0), y: p0.y + k * radius * cos(a0))
        let c2 = CGPoint(x: p3.x + k * radius * sin(a1), y: p3.y - k * radius * cos(a1))
        addCurve(to: p3, control1: c1, control2: c2, transform: transform)
    }

    public func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) {
        let unit = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: rect.width / 2, y: rect.height / 2)
            .concatenating(transform)
        // Always a new subpath, never a line from the current point.
        move(to: CGPoint(x: 1, y: 0), transform: unit)
        appendArcPieces(center: .zero, radius: 1, startAngle: 0, sweep: 2 * .pi, transform: unit)
        closeSubpath()
    }

    /// A rounded rect; corners are clamped to half the side as CoreGraphics requires.
    public func addRoundedRect(in rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat, transform: CGAffineTransform = .identity) {
        let rx = max(0, min(cornerWidth, rect.width / 2))
        let ry = max(0, min(cornerHeight, rect.height / 2))
        guard rx > 0, ry > 0 else { return addRect(rect, transform: transform) }
        let corners: [(CGPoint, CGFloat)] = [
            (CGPoint(x: rect.maxX - rx, y: rect.minY + ry), -.pi / 2),
            (CGPoint(x: rect.maxX - rx, y: rect.maxY - ry), 0),
            (CGPoint(x: rect.minX + rx, y: rect.maxY - ry), .pi / 2),
            (CGPoint(x: rect.minX + rx, y: rect.minY + ry), .pi)
        ]
        move(to: CGPoint(x: rect.minX + rx, y: rect.minY), transform: transform)
        for (center, start) in corners {
            let quarter = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: rx, y: ry).concatenating(transform)
            addArc(center: .zero, radius: 1, startAngle: start, endAngle: start + .pi / 2, clockwise: false, transform: quarter)
        }
        closeSubpath()
    }

    public func addPath(_ path: CGPath, transform: CGAffineTransform = .identity) {
        segments.append(contentsOf: path.segments.map { $0.applying(transform) })
    }
}
