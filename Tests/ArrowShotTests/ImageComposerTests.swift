import BigArrowCore
@testable import BigArrowOverlay
import CoreGraphics
import Foundation
import Testing

/// The arrow is baked into the screenshot: same pixel size, pixels changed only around the arrow.
@MainActor
struct ImageComposerTests {
    static func blank(width: Int, height: Int) -> CGImage {
        let canvas = Canvas(size: CGSize(width: width, height: height), scale: 1)
        return canvas.render { context in
            context.setFillColor(CGColor(gray: 0.95, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    static func layout(_ image: CGImage, scale: CGFloat, target: TargetShape) -> (OverlayLayout, SignImage, SignAppearance) {
        let display = ImageComposer.display(for: image, scale: scale)
        let appearance = SignAppearance(color: try! ArrowColor.parse("red"), size: .small, corners: .round)
        let sign = SignRenderer.render(text: try! SignText.parse("1. Click Save"), appearance: appearance, display: display)
        let request = OverlayLayout.Request(
            target: target, display: display, signSize: sign.size, style: .arrow, size: .small, forced: nil
        )
        return (OverlayLayout.plan(request), sign, appearance)
    }

    @Test func keepsPixelSizeAndChangesPixels() throws {
        let base = Self.blank(width: 1280, height: 800)
        let (layout, sign, appearance) = Self.layout(base, scale: 1, target: .point(CGPoint(x: 900, y: 300)))
        let out = ImageComposer.composite(base, layout: layout, sign: sign, appearance: appearance)
        #expect(out.width == 1280 && out.height == 800)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("arrowshot-test-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try ImageComposer.write(out, scale: 2, to: url)
        let (loaded, scale) = try ImageComposer.load(url)
        #expect(loaded.width == 1280 && scale == 2)
        #expect(layout.display.localBounds.contains(layout.signRect))
    }

    @Test func retinaScaleKeepsTheArrowInPoints() {
        let base = Self.blank(width: 2560, height: 1600)
        let (layout, sign, _) = Self.layout(base, scale: 2, target: .point(CGPoint(x: 900, y: 300)))
        #expect(layout.display.frame.size == CGSize(width: 1280, height: 800))
        #expect(sign.size.height < 100)
    }
}
