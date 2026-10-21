@_exported import CoreGraphics
import CCairo
import Foundation

public struct CAShapeLayerLineCap: Hashable, Sendable {
    let cap: CGLineCap
    public static let butt = CAShapeLayerLineCap(cap: .butt)
    public static let round = CAShapeLayerLineCap(cap: .round)
    public static let square = CAShapeLayerLineCap(cap: .square)
}

public struct CAShapeLayerLineJoin: Hashable, Sendable {
    let join: CGLineJoin
    public static let miter = CAShapeLayerLineJoin(join: .miter)
    public static let round = CAShapeLayerLineJoin(join: .round)
    public static let bevel = CAShapeLayerLineJoin(join: .bevel)
}

/// The part of Core Animation that `render(in:)` needs: a tree of layers with geometry, image
/// contents, opacity and a drop shadow, drawn once into a context. No animation.
open class CALayer {
    public var bounds = CGRect.zero
    public var position = CGPoint.zero
    public var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    public var sublayers: [CALayer]?
    public var contents: Any?
    public var contentsScale: CGFloat = 1
    public var opacity: Float = 1
    public var isHidden = false
    public var shadowColor: CGColor? = CGColor(gray: 0, alpha: 1)
    public var shadowOpacity: Float = 0
    public var shadowRadius: CGFloat = 3
    public var shadowOffset = CGSize(width: 0, height: -3)

    public init() {}

    /// Derived from bounds, position and anchor point, as in Core Animation.
    public var frame: CGRect {
        get {
            CGRect(
                x: position.x - anchorPoint.x * bounds.width, y: position.y - anchorPoint.y * bounds.height,
                width: bounds.width, height: bounds.height
            )
        }
        set {
            bounds.size = newValue.size
            position = CGPoint(
                x: newValue.minX + anchorPoint.x * newValue.width, y: newValue.minY + anchorPoint.y * newValue.height
            )
        }
    }

    public func addSublayer(_ layer: CALayer) {
        sublayers = (sublayers ?? []) + [layer]
    }

    /// Draws the layer and its sublayers in the layer's own coordinate space.
    public func render(in context: CGContext) {
        guard !isHidden, opacity > 0 else { return }
        if shadowOpacity > 0, let shadowColor {
            context.drawWithShadow(
                offset: shadowOffset, radius: shadowRadius, color: shadowColor, opacity: CGFloat(shadowOpacity),
                renderTree
            )
        } else {
            renderTree(context)
        }
    }

    private func renderTree(_ context: CGContext) {
        context.saveGState()
        // Opacity applies to the layer and its sublayers as one group.
        let grouped = opacity < 1
        if grouped { cairo_push_group(context.cairo) }
        drawContents(in: context)
        for layer in sublayers ?? [] {
            context.saveGState()
            let frame = layer.frame
            context.translateBy(x: frame.minX - layer.bounds.minX, y: frame.minY - layer.bounds.minY)
            layer.render(in: context)
            context.restoreGState()
        }
        if grouped {
            cairo_pop_group_to_source(context.cairo)
            cairo_paint_with_alpha(context.cairo, Double(opacity))
        }
        context.restoreGState()
    }

    /// Image contents fill the bounds.
    open func drawContents(in context: CGContext) {
        guard let image = contents as? CGImage else { return }
        context.draw(image, in: bounds)
    }
}

open class CAShapeLayer: CALayer {
    public var path: CGPath?
    public var fillColor: CGColor? = CGColor(gray: 0, alpha: 1)
    public var strokeColor: CGColor?
    public var lineWidth: CGFloat = 1
    public var lineCap = CAShapeLayerLineCap.butt
    public var lineJoin = CAShapeLayerLineJoin.miter

    open override func drawContents(in context: CGContext) {
        guard let path else { return }
        if let fillColor {
            context.beginPath()
            context.addPath(path)
            context.setFillColor(fillColor)
            context.fillPath()
        }
        if let strokeColor, lineWidth > 0 {
            context.beginPath()
            context.addPath(path)
            context.setStrokeColor(strokeColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(lineCap.cap)
            context.setLineJoin(lineJoin.join)
            context.strokePath()
        }
    }
}
