#if os(Linux)
import AppKit
import BigArrowCore
import CCairo

/// SignTextLayout.swift for Linux: the sign's sentence laid out once with Pango, centred and
/// word-wrapped, each copy chip an inline box of its size on the cap height. Drawing uses the same
/// layout, so a chip's click area is exactly where it is drawn.
struct SignTextLayout {
    let size: CGSize
    let lines: Int
    /// Each chip in top-left points of the text block, in reading order.
    let chips: [CGRect]
    private let text: LaidOutText
    private let origin: CGPoint

    /// Lays out `text` in at most `maxWidth`, centred, `copied` showing a check instead of the copy icon.
    init(_ text: SignText, style: Style, maxWidth: CGFloat, copied: Int? = nil) {
        let laidOut = LaidOutText(text, style: style, maxWidth: maxWidth, copied: copied)
        var logical = PangoRectangle()
        pango_layout_get_extents(laidOut.layout, nil, &logical)
        let used = CGRect(
            x: CGFloat(logical.x) / CGFloat(PANGO_SCALE), y: CGFloat(logical.y) / CGFloat(PANGO_SCALE),
            width: CGFloat(logical.width) / CGFloat(PANGO_SCALE), height: CGFloat(logical.height) / CGFloat(PANGO_SCALE)
        )
        self.text = laidOut
        origin = used.origin
        size = CGSize(width: ceil(used.width), height: ceil(used.height))
        lines = max(1, Int(pango_layout_get_line_count(laidOut.layout)))
        chips = laidOut.chips.map { chip in
            let box = laidOut.box(of: chip)
            return box.offsetBy(dx: -used.minX, dy: -used.minY)
        }
    }

    /// Draws into `rect`, bottom-left points of the sign.
    func draw(in context: CGContext, rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX - origin.x, y: rect.maxY + origin.y)
        context.scaleBy(x: 1, y: -1)
        let color = text.style.appearance.textTint
        cairo_set_source_rgb(context.cairo, color.red, color.green, color.blue)
        cairo_move_to(context.cairo, 0, 0)
        pango_cairo_show_layout(context.cairo, text.layout)
        // The chips: Pango only reserved their room. y is down here, so images draw upright as is.
        for chip in text.chips {
            let box = text.box(of: chip)
            cairo_save(context.cairo)
            cairo_translate(context.cairo, box.minX, box.minY)
            cairo_scale(context.cairo, box.width / CGFloat(chip.image.width), box.height / CGFloat(chip.image.height))
            cairo_set_source_surface(context.cairo, chip.image.cairoSurface, 0, 0)
            cairo_pattern_set_filter(cairo_get_source(context.cairo), CAIRO_FILTER_GOOD)
            cairo_paint(context.cairo)
            cairo_restore(context.cairo)
        }
        context.restoreGState()
    }

    /// Font, colour and chip look of one sign at one font size.
    struct Style {
        let fontSize: CGFloat
        let appearance: SignAppearance
        let scale: CGFloat
    }
}

/// The Pango layout behind one SignTextLayout, and the chips it holds room for.
final class LaidOutText {
    struct Chip {
        /// Byte offset of the chip's placeholder character in the layout's UTF-8 text.
        let index: Int32
        let image: CGImage
        /// The chip's box around the baseline, y up (as an attachment's bounds).
        let bounds: CGRect
    }

    let layout: OpaquePointer
    let style: SignTextLayout.Style
    private(set) var chips: [Chip] = []

    /// U+FFFC, the object replacement character, stands in for each chip.
    static let placeholder = "\u{FFFC}"

    init(_ text: SignText, style: SignTextLayout.Style, maxWidth: CGFloat, copied: Int?) {
        self.style = style
        let context = PangoText.makeContext()
        layout = pango_layout_new(context)
        g_object_unref(UnsafeMutableRawPointer(context))
        let font = SignRenderer.font(style.fontSize)
        let description = font.makePangoDescription()
        pango_layout_set_font_description(layout, description)
        pango_font_description_free(description)
        pango_layout_set_width(layout, Int32(maxWidth * CGFloat(PANGO_SCALE)))
        pango_layout_set_wrap(layout, PANGO_WRAP_WORD)
        pango_layout_set_alignment(layout, PANGO_ALIGN_CENTER)

        var string = ""
        var chip = 0
        for segment in text.segments {
            switch segment {
            case .plain(let plain):
                string += plain
            case .copy(let value):
                let look = CopyChip(value: value, fontSize: style.fontSize, maxWidth: maxWidth, appearance: style.appearance)
                let (image, bounds) = look.attachment(icon: chip == copied ? .check : .copy, font: font, scale: style.scale)
                chips.append(Chip(index: Int32(string.utf8.count), image: image, bounds: bounds))
                string += Self.placeholder
                chip += 1
            }
        }
        pango_layout_set_text(layout, string, -1)

        let attributes = pango_attr_list_new()
        let length = UInt32(Self.placeholder.utf8.count)
        for chip in chips {
            // Pango's logical rect is y down from the baseline; the bounds are y up.
            var box = PangoRectangle(
                x: 0, y: Int32(-chip.bounds.maxY * CGFloat(PANGO_SCALE)),
                width: Int32(chip.bounds.width * CGFloat(PANGO_SCALE)), height: Int32(chip.bounds.height * CGFloat(PANGO_SCALE))
            )
            let shape = pango_attr_shape_new(&box, &box)!
            shape.pointee.start_index = UInt32(chip.index)
            shape.pointee.end_index = UInt32(chip.index) + length
            pango_attr_list_insert(attributes, shape)
        }
        pango_layout_set_attributes(layout, attributes)
        pango_attr_list_unref(attributes)
    }

    deinit {
        g_object_unref(UnsafeMutableRawPointer(layout))
    }

    /// Where a chip landed, top-left points of the layout.
    func box(of chip: Chip) -> CGRect {
        var position = PangoRectangle()
        pango_layout_index_to_pos(layout, chip.index, &position)
        var line: Int32 = 0
        var x: Int32 = 0
        pango_layout_index_to_line_x(layout, chip.index, 0, &line, &x)
        let baseline = CGFloat(baseline(ofLine: line)) / CGFloat(PANGO_SCALE)
        let left = CGFloat(min(position.x, position.x + position.width)) / CGFloat(PANGO_SCALE)
        return CGRect(
            x: left, y: baseline - chip.bounds.maxY, width: chip.bounds.width, height: chip.bounds.height
        )
    }

    private func baseline(ofLine target: Int32) -> Int32 {
        let iterator = pango_layout_get_iter(layout)
        defer { pango_layout_iter_free(iterator) }
        var line: Int32 = 0
        while line < target, pango_layout_iter_next_line(iterator) != 0 { line += 1 }
        return pango_layout_iter_get_baseline(iterator)
    }
}
#endif
