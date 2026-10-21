import CCairo
import Foundation

/// A system font for Linux builds, described for Pango: a design (a fontconfig family list, the
/// first installed one wins), a weight and a size in points. Ubuntu ships no heavy rounded face,
/// so the rounded design uses Nunito when it is installed and Ubuntu Sans otherwise.
public final class NSFontDescriptor: @unchecked Sendable {
    public struct SystemDesign: Hashable, Sendable {
        let families: String
        public static let `default` = SystemDesign(families: "Ubuntu Sans, Ubuntu, Noto Sans, DejaVu Sans, sans-serif")
        public static let rounded = SystemDesign(families: "Nunito, Ubuntu Sans, Ubuntu, Noto Sans, DejaVu Sans, sans-serif")
        public static let monospaced = SystemDesign(
            families: "Ubuntu Sans Mono, Ubuntu Mono, Noto Sans Mono, DejaVu Sans Mono, monospace"
        )
        public static let serif = SystemDesign(families: "Noto Serif, DejaVu Serif, serif")
    }

    let design: SystemDesign
    let weight: NSFont.Weight
    let size: CGFloat

    init(design: SystemDesign, weight: NSFont.Weight, size: CGFloat) {
        (self.design, self.weight, self.size) = (design, weight, size)
    }

    public func withDesign(_ design: SystemDesign) -> NSFontDescriptor? {
        NSFontDescriptor(design: design, weight: weight, size: size)
    }
}

public final class NSFont: @unchecked Sendable {
    public struct Weight: RawRepresentable, Hashable, Sendable {
        public let rawValue: CGFloat
        public init(rawValue: CGFloat) { self.rawValue = rawValue }

        public static let ultraLight = Weight(rawValue: -0.8)
        public static let thin = Weight(rawValue: -0.6)
        public static let light = Weight(rawValue: -0.4)
        public static let regular = Weight(rawValue: 0)
        public static let medium = Weight(rawValue: 0.23)
        public static let semibold = Weight(rawValue: 0.3)
        public static let bold = Weight(rawValue: 0.4)
        public static let heavy = Weight(rawValue: 0.56)
        public static let black = Weight(rawValue: 0.62)

        /// The CSS-style weight Pango and fontconfig match on.
        var pango: UInt32 {
            switch rawValue {
            case 0.56...: 900
            case 0.4..<0.56: 700
            case 0.3..<0.4: 600
            case 0.23..<0.3: 500
            case 0..<0.23: 400
            case -0.4..<0: 300
            default: 200
            }
        }
    }

    public let fontDescriptor: NSFontDescriptor
    public var pointSize: CGFloat { fontDescriptor.size }

    init(_ descriptor: NSFontDescriptor) {
        fontDescriptor = descriptor
    }

    public convenience init?(descriptor: NSFontDescriptor, size: CGFloat) {
        self.init(NSFontDescriptor(design: descriptor.design, weight: descriptor.weight, size: size))
    }

    public static func systemFont(ofSize size: CGFloat, weight: Weight) -> NSFont {
        NSFont(NSFontDescriptor(design: .default, weight: weight, size: size))
    }

    public static func monospacedSystemFont(ofSize size: CGFloat, weight: Weight) -> NSFont {
        NSFont(NSFontDescriptor(design: .monospaced, weight: weight, size: size))
    }

    /// A new `PangoFontDescription`; free it with `pango_font_description_free`.
    public func makePangoDescription() -> OpaquePointer {
        let description = pango_font_description_new()!
        pango_font_description_set_family(description, fontDescriptor.design.families)
        pango_font_description_set_weight(description, PangoWeight(rawValue: fontDescriptor.weight.pango))
        pango_font_description_set_absolute_size(description, Double(pointSize) * Double(PANGO_SCALE))
        return description
    }

    public var ascender: CGFloat { metrics.ascender }
    /// Negative, below the baseline, as on macOS.
    public var descender: CGFloat { metrics.descender }
    public var capHeight: CGFloat { metrics.capHeight }

    private lazy var metrics: (ascender: CGFloat, descender: CGFloat, capHeight: CGFloat) = {
        let context = PangoText.makeContext()
        defer { g_object_unref(UnsafeMutableRawPointer(context)) }
        let description = makePangoDescription()
        defer { pango_font_description_free(description) }
        let fontMetrics = pango_context_get_metrics(context, description, nil)
        defer { pango_font_metrics_unref(fontMetrics) }
        let ascent = CGFloat(pango_font_metrics_get_ascent(fontMetrics)) / CGFloat(PANGO_SCALE)
        let descent = CGFloat(pango_font_metrics_get_descent(fontMetrics)) / CGFloat(PANGO_SCALE)
        // Pango has no cap height; measure an "H".
        let layout = pango_layout_new(context)!
        defer { g_object_unref(UnsafeMutableRawPointer(layout)) }
        pango_layout_set_font_description(layout, description)
        pango_layout_set_text(layout, "H", -1)
        var ink = PangoRectangle()
        pango_layout_get_extents(layout, &ink, nil)
        let baseline = CGFloat(pango_layout_get_baseline(layout))
        return (ascent, -descent, (baseline - CGFloat(ink.y)) / CGFloat(PANGO_SCALE))
    }()
}

/// Pango contexts that lay text out the same way at every scale: unhinted metrics, so a layout
/// measured in points is exactly where it draws on a 2x canvas.
public enum PangoText {
    /// A new `PangoContext`; release it with `g_object_unref`.
    public static func makeContext() -> OpaquePointer {
        let context = pango_font_map_create_context(pango_cairo_font_map_get_default())!
        let options = cairo_font_options_create()
        cairo_font_options_set_hint_metrics(options, CAIRO_HINT_METRICS_OFF)
        cairo_font_options_set_hint_style(options, CAIRO_HINT_STYLE_NONE)
        cairo_font_options_set_antialias(options, CAIRO_ANTIALIAS_GRAY)
        pango_cairo_context_set_font_options(context, options)
        cairo_font_options_destroy(options)
        return context
    }
}
