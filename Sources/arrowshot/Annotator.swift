import BigArrowCore
import BigArrowOverlay
import Foundation

/// The `--json` result: everything in pixels of the written image.
struct AnnotateResult: Codable {
    var ok = true
    let output: String
    let width: Int
    let height: Int
    let scale: Double
    /// The target: x, y (and w, h for --rect).
    let target: [Double]
    /// Where the sign landed: x, y, w, h. Keep the next arrow's target clear of it.
    let sign: [Double]
    let direction: String
}

/// Reads a screenshot, plans the arrow on it as if it were a display, and writes the result.
@MainActor
struct Annotator {
    let options: AnnotationOptions

    func run(input: URL, output: URL) throws -> AnnotateResult {
        let target = try Self.target(options)
        guard let raw = options.text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            throw BigArrowError.badInput("--text must not be empty, write the action: '1. Click Save'")
        }
        let (image, dpiScale) = try ImageComposer.load(input)
        let scale = CGFloat(options.scale ?? dpiScale.map(Double.init) ?? 1)
        guard scale > 0, scale.isFinite else { throw BigArrowError.badInput("--scale must be more than 0") }
        let display = ImageComposer.display(for: image, scale: scale)
        let shape = Self.points(target, scale: scale)
        guard display.localBounds.contains(shape.anchor) else {
            throw BigArrowError.unresolvable("target \(Self.describe(target)) is outside the \(image.width)x\(image.height) image")
        }
        let appearance = try appearance()
        let sign = SignRenderer.render(text: try SignText.parse(raw), appearance: appearance, display: display)
        let request = OverlayLayout.Request(
            target: shape, display: display, signSize: sign.size, style: try ArrowStyle.parse(options.style),
            size: appearance.size, forced: try ApproachDirection.parse(options.from),
            corners: appearance.corners, shape: try ArrowShape.parse(options.shape),
            others: try options.avoid.map { try NumberListParser.rect($0) }.map { Self.points(.rect($0), scale: scale).rect ?? .null }
        )
        let layout = OverlayLayout.plan(request)
        let composed = ImageComposer.composite(image, layout: layout, sign: sign, appearance: appearance)
        try ImageComposer.write(composed, scale: scale, to: output)
        let signRect = layout.signRect
        return AnnotateResult(
            output: output.path, width: composed.width, height: composed.height, scale: Double(scale),
            target: Self.numbers(target),
            sign: [signRect.minX, signRect.minY, signRect.width, signRect.height].map { Double(($0 * scale).rounded()) },
            direction: layout.direction.rawValue
        )
    }

    func appearance() throws -> SignAppearance {
        var appearance = SignAppearance(
            color: try ArrowColor.parse(options.color), size: try ArrowSize.parse(options.size),
            corners: try SignCorners.parse(options.corners)
        )
        appearance.border = try ArrowBorder.parse(options.border)
        let tints: [(WritableKeyPath<SignAppearance, ArrowColor?>, String?)] = [
            (\.borderColor, options.borderColor), (\.textColor, options.textColor), (\.edgeColor, options.edgeColor)
        ]
        for (path, raw) in tints {
            if let raw { appearance[keyPath: path] = try ArrowColor.parse(raw) }
        }
        return appearance
    }

    static func target(_ options: AnnotationOptions) throws -> TargetShape {
        switch (options.at, options.rect) {
        case (let at?, nil): return .point(try NumberListParser.point(at))
        case (nil, let rect?): return .rect(try NumberListParser.rect(rect))
        default: throw BigArrowError.badInput("give exactly one target: --at x,y or --rect x,y,w,h (image pixels)")
        }
    }

    /// Image pixels to the image's points.
    static func points(_ shape: TargetShape, scale: CGFloat) -> TargetShape {
        switch shape {
        case .point(let point): .point(CGPoint(x: point.x / scale, y: point.y / scale))
        case .rect(let rect):
            .rect(CGRect(x: rect.minX / scale, y: rect.minY / scale, width: rect.width / scale, height: rect.height / scale))
        }
    }

    static func numbers(_ shape: TargetShape) -> [Double] {
        switch shape {
        case .point(let point): [point.x, point.y]
        case .rect(let rect): [rect.minX, rect.minY, rect.width, rect.height]
        }
    }

    static func describe(_ shape: TargetShape) -> String {
        numbers(shape).map { String(format: "%g", $0) }.joined(separator: ",")
    }
}
