import AppKit
import BigArrowCore
import ImageIO
import UniformTypeIdentifiers

/// Bakes an arrow into a screenshot: the screenshot is the "display", the arrow's layer tree is
/// rendered on top of it, and the result is one flat PNG. Nothing is shown on screen.
@MainActor
public enum ImageComposer {
    /// A screenshot as a display: its pixels at `scale` pixels per point, top-left origin.
    public static func display(for image: CGImage, scale: CGFloat) -> Display {
        let frame = CGRect(x: 0, y: 0, width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        return Display(index: 0, id: 0, frame: frame, visibleFrame: frame, scale: scale)
    }

    /// The screenshot with the arrow drawn over it, same pixel size as the screenshot.
    public static func composite(_ base: CGImage, layout: OverlayLayout, sign: SignImage, appearance: SignAppearance) -> CGImage {
        let layers = OverlayLayers(layout: layout, sign: sign, appearance: appearance)
        let bounds = layout.display.localBounds
        return Canvas(size: bounds.size, scale: layout.display.scale).render { context in
            context.draw(base, in: bounds)
            layers.root.render(in: context)
        }
    }

    /// Loads the first image of a file plus its pixels per point from the DPI metadata
    /// (`screencapture` writes 144 DPI on Retina displays), nil when the file has none.
    public static func load(_ url: URL) throws -> (CGImage, CGFloat?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw BigArrowError.badInput("cannot read an image at \(url.path)")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let dpi = properties?[kCGImagePropertyDPIWidth] as? Double
        return (image, dpi.flatMap { $0 > 0 ? CGFloat(($0 / 72 * 4).rounded() / 4) : nil })
    }

    /// Writes a PNG with DPI metadata for `scale`, so a second pass over the file keeps the size.
    public static func write(_ image: CGImage, scale: CGFloat, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw BigArrowError.badInput("cannot write a PNG to \(url.path)")
        }
        let dpi = Double(scale * 72)
        let properties = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw BigArrowError.badInput("cannot write a PNG to \(url.path)")
        }
    }
}
