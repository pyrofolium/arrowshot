#if os(Linux)
import AppKit
import BigArrowCore
import CCairo

/// CopyChip.swift for Linux: the same chip (sizes, rounded shape, Feather icon), with the value
/// measured and drawn by Pango instead of TextKit, and handed to the sign's layout as an image
/// plus its box around the baseline instead of an NSTextAttachment.
struct CopyChip {
    let value: String
    let fontSize: CGFloat
    let maxWidth: CGFloat
    let appearance: SignAppearance

    /// Shares of the sign's font size.
    static let valueShare: CGFloat = 0.78
    static let heightShare: CGFloat = 1.12
    static let paddingShare: CGFloat = 0.36
    static let gapShare: CGFloat = 0.28
    static let iconShare: CGFloat = 0.74

    var valueFont: NSFont { NSFont.monospacedSystemFont(ofSize: (fontSize * Self.valueShare).rounded(), weight: .bold) }
    var height: CGFloat { ceil(fontSize * Self.heightShare) }
    var padding: CGFloat { (fontSize * Self.paddingShare).rounded() }
    var iconSize: CGFloat { (fontSize * Self.iconShare).rounded() }
    var gap: CGFloat { (fontSize * Self.gapShare).rounded() }

    var valueWidth: CGFloat {
        let natural = ceil(ValueText(value: value, font: valueFont, width: nil).width)
        return min(natural, maxWidth - padding * 2 - gap - iconSize)
    }

    var size: CGSize { CGSize(width: padding * 2 + valueWidth + gap + iconSize, height: height) }

    /// The chip's image and its box relative to the baseline (y up), centred on the cap height of
    /// the sign's font, as the macOS attachment's bounds.
    func attachment(icon: FeatherIcon, font: NSFont, scale: CGFloat) -> (image: CGImage, bounds: CGRect) {
        let bounds = CGRect(x: 0, y: ((font.capHeight - height) / 2).rounded(), width: size.width, height: size.height)
        return (image(icon: icon, scale: scale), bounds)
    }

    func image(icon: FeatherIcon, scale: CGFloat) -> CGImage {
        Canvas(size: size, scale: scale).render { context in
            let shape = CGRect(origin: .zero, size: size)
            let corner = appearance.corners == .round ? height / 2 : height * 0.18
            context.addPath(CGPath(roundedRect: shape, cornerWidth: corner, cornerHeight: corner, transform: nil))
            context.setFillColor(appearance.textTint.cgColor)
            context.fillPath()
            drawValue(in: context)
            drawIcon(icon, in: context, at: CGPoint(x: padding + valueWidth + gap, y: (height - iconSize) / 2))
        }
    }

    func drawValue(in context: CGContext) {
        let font = valueFont
        let lineHeight = ceil(font.ascender - font.descender)
        let rect = CGRect(x: padding, y: ((height - lineHeight) / 2).rounded(), width: valueWidth, height: lineHeight)
        let text = ValueText(value: value, font: font, width: valueWidth)
        let color = appearance.color
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        cairo_set_source_rgb(context.cairo, color.red, color.green, color.blue)
        cairo_move_to(context.cairo, 0, (lineHeight - text.height) / 2)
        pango_cairo_show_layout(context.cairo, text.layout)
        context.restoreGState()
    }

    /// Feather's 24-unit, y-down outline scaled into the icon square and stroked like the original.
    func drawIcon(_ icon: FeatherIcon, in context: CGContext, at origin: CGPoint) {
        let unit = iconSize / FeatherIcon.viewBox
        var transform = CGAffineTransform(translationX: origin.x, y: origin.y + iconSize).scaledBy(x: unit, y: -unit)
        guard let path = icon.path.copy(using: &transform) else { return }
        context.addPath(path)
        context.setStrokeColor(appearance.color.cgColor)
        context.setLineWidth(FeatherIcon.strokeWidth * unit * 1.15)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }
}

/// One line of the chip's value; with a width, elided in the middle like `.byTruncatingMiddle`.
final class ValueText {
    let layout: OpaquePointer
    let width: CGFloat
    let height: CGFloat

    init(value: String, font: NSFont, width: CGFloat?) {
        let context = PangoText.makeContext()
        layout = pango_layout_new(context)
        g_object_unref(UnsafeMutableRawPointer(context))
        let description = font.makePangoDescription()
        pango_layout_set_font_description(layout, description)
        pango_font_description_free(description)
        pango_layout_set_single_paragraph_mode(layout, 1)
        if let width {
            pango_layout_set_width(layout, Int32(width * CGFloat(PANGO_SCALE)))
            pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_MIDDLE)
        }
        pango_layout_set_text(layout, value, -1)
        var logical = PangoRectangle()
        pango_layout_get_extents(layout, nil, &logical)
        self.width = CGFloat(logical.width) / CGFloat(PANGO_SCALE)
        height = CGFloat(logical.height) / CGFloat(PANGO_SCALE)
    }

    deinit {
        g_object_unref(UnsafeMutableRawPointer(layout))
    }
}
#endif
