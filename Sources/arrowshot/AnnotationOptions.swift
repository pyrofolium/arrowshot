import ArgumentParser

/// Shorthand for an option's help text with a value name.
func help(_ text: String, _ value: String) -> ArgumentHelp {
    ArgumentHelp(text, valueName: value)
}

/// What to point at and what the sign says. Coordinates are pixels of the image.
struct AnnotationOptions: ParsableArguments {
    @Option(help: help("Point at pixel X,Y of the image (top-left origin).", "x,y"))
    var at: String?

    @Option(help: help("Draw a box around pixels x,y,w,h and point at it.", "x,y,w,h"))
    var rect: String?

    @Option(help: help("Keep the sign off pixels x,y,w,h, e.g. an earlier arrow's sign from --json. Repeatable.", "x,y,w,h"))
    var avoid: [String] = []

    @Option(help: help("The sign: a short action label, e.g. '1. Click Save'.", "text"))
    var text: String?

    @Option(help: help(
        "Preferred side for the sign (another side if it does not fit there): auto, top-left, top, top-right, "
            + "right, bottom-right, bottom, bottom-left, left.", "side"
    ))
    var from = "auto"

    @Option(help: help("S, M or L, in points of the image (see --scale).", "size"))
    var size = "S"

    @Option(help: help("arrow, ring or box.", "style"))
    var style = "arrow"

    @Option(help: help("red, orange, yellow, green, teal, blue, purple, pink, black, white, or hex like #FF3B1F / #F31.", "colour"))
    var color = "red"

    @Option(name: .customLong("border-color"), help: help("Border colour (default: white, dark on light arrows).", "colour"))
    var borderColor: String?

    @Option(name: .customLong("text-color"), help: help("Sign text colour (default: white, dark on light arrows).", "colour"))
    var textColor: String?

    @Option(name: .customLong("edge-color"), help: help("Thin line colour of --border white-black and black (default: black).", "colour"))
    var edgeColor: String?

    @Option(help: help("Shaft shape: bend, straight, zigzag or spiral.", "shape"))
    var shape = "bend"

    @Option(help: help("Sign corners: round or sharp.", "corners"))
    var corners = "round"

    @Option(help: help(
        "shadow (white border and drop shadow), white-black (white border, thin black edge) or black (thin black outline).",
        "border"
    ))
    var border = "shadow"

    @Option(help: help(
        "Image pixels per point: 2 for a Retina capture, 1 for a 1x browser screenshot. "
            + "Default: from the PNG's DPI (144 DPI = 2), else 1. Larger scale = the arrow covers more pixels.",
        "n"
    ))
    var scale: Double?

    @Flag(help: "Print a JSON result to stdout (errors as JSON on stderr).")
    var json = false

    /// True when any arrow option was given, so `capture` knows whether to annotate.
    var wantsArrow: Bool { text != nil || at != nil || rect != nil }
}
