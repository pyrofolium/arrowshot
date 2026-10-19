import ArgumentParser
import Foundation

struct AnnotateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "annotate",
        abstract: "Draw an arrow with a sign into an existing screenshot.",
        discussion: """
        Example: arrowshot annotate shot.png -o step1.png --rect 120,80,200,44 --text "1. Click Save"
        For a second arrow, run it again on step1.png. -o may be the input file itself.
        """
    )

    @Argument(help: help("The screenshot (PNG, JPEG, ...).", "image"))
    var input: String

    @Option(name: [.short, .customLong("output")], help: help("Where to write the PNG (default: overwrite the input).", "file"))
    var output: String?

    @OptionGroup var arrow: AnnotationOptions

    func run() throws {
        try MainActor.assumeIsolated {
            let result = try Annotator(options: arrow).run(
                input: URL(fileURLWithPath: input), output: URL(fileURLWithPath: output ?? input)
            )
            Output.report(result, json: arrow.json)
        }
    }
}

extension Output {
    static func report(_ result: AnnotateResult, json: Bool) {
        if json {
            Self.json(result)
            return
        }
        let sign = result.sign.map { String(Int($0)) }.joined(separator: ",")
        print("arrowshot: wrote \(result.output) (\(result.width)x\(result.height), sign at \(sign) on the \(result.direction))")
    }
}
