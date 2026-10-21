/// The one uniform type arrowshot names, for Linux builds.
public struct UTType: Hashable, Sendable {
    public let identifier: String

    public init(_ identifier: String) {
        self.identifier = identifier
    }

    public static let png = UTType("public.png")
}
