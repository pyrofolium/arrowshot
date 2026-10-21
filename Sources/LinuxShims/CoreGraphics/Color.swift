import Foundation

/// A named colour space. Linux builds draw everything in sRGB, so the name is all it carries.
public final class CGColorSpace: @unchecked Sendable {
    public let name: String?

    public init?(name: String) {
        self.name = name
    }

    init(unnamed: Void) {
        name = nil
    }

    public static let sRGB = "kCGColorSpaceSRGB"
    public static let genericRGBLinear = "kCGColorSpaceGenericRGBLinear"
    public static let displayP3 = "kCGColorSpaceDisplayP3"
}

public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace {
    CGColorSpace(unnamed: ())
}

/// An sRGB colour with alpha, not premultiplied.
public final class CGColor: @unchecked Sendable, Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        (self.red, self.green, self.blue, self.alpha) = (red, green, blue, alpha)
    }

    public convenience init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public convenience init(gray: CGFloat, alpha: CGFloat) {
        self.init(srgbRed: gray, green: gray, blue: gray, alpha: alpha)
    }

    public var components: [CGFloat]? { [red, green, blue, alpha] }
    public var numberOfComponents: Int { 4 }
    public var colorSpace: CGColorSpace? { CGColorSpace(name: CGColorSpace.sRGB) }

    public func copy(alpha: CGFloat) -> CGColor? {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public static func == (lhs: CGColor, rhs: CGColor) -> Bool {
        (lhs.red, lhs.green, lhs.blue, lhs.alpha) == (rhs.red, rhs.green, rhs.blue, rhs.alpha)
    }

    public static let black = CGColor(gray: 0, alpha: 1)
    public static let white = CGColor(gray: 1, alpha: 1)
    public static let clear = CGColor(gray: 0, alpha: 0)
}
