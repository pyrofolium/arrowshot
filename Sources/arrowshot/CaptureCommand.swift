import ArgumentParser
import BigArrowCore
import BigArrowTargeting
import Foundation

struct CaptureCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "capture",
        abstract: "Take a screenshot (a window, a region or a display), optionally with an arrow baked in.",
        discussion: """
        A window is captured even when other windows cover it, and nothing is raised or focused.
        Needs Screen Recording for the app that runs your shell. Arrow coordinates are pixels of
        the captured image, so take a plain capture first, find the target, then annotate it.

          arrowshot capture --window "Google Chrome" -o shot.png
          arrowshot annotate shot.png -o step1.png --rect 120,80,200,44 --text "1. Click Save"
          arrowshot capture --window "Google Chrome:FruitScope" -o step1.png --at 300,200 --text "1. Open the map"
        """
    )

    @Option(name: [.short, .customLong("output")], help: help("Where to write the PNG.", "file"))
    var output: String

    @Option(help: help("Capture an app's front window, optionally by title: 'Safari' or 'Google Chrome:FruitScope'.", "app[:title]"))
    var window: String?

    @Option(help: help("Capture the region x,y,w,h in global top-left screen points.", "x,y,w,h"))
    var region: String?

    @Option(help: help("Capture display N (1-based). Default when nothing else is given: the main display.", "n"))
    var display: Int?

    @Flag(name: .customLong("window-shadow"), help: "Keep the macOS drop shadow around a --window capture.")
    var windowShadow = false

    @OptionGroup var arrow: AnnotationOptions

    func run() throws {
        try MainActor.assumeIsolated {
            guard Permission.screenRecording.isGranted else {
                throw BigArrowError.permission(
                    "capturing the screen needs Screen Recording for \(ResponsibleProcess.describeForMessage()): "
                        + "turn it on in \(Permission.screenRecording.settingsPane), then restart that app"
                )
            }
            let url = URL(fileURLWithPath: output)
            try Screencapture.run(try source(), to: url)
            guard arrow.wantsArrow else {
                if arrow.json { Output.json(CaptureResult(output: url.path)) } else { Output.print("arrowshot: wrote \(url.path)") }
                return
            }
            Output.report(try Annotator(options: arrow).run(input: url, output: url), json: arrow.json)
        }
    }

    @MainActor
    func source() throws -> Screencapture.Source {
        let given = [window != nil, region != nil, display != nil].filter { $0 }.count
        guard given <= 1 else { throw BigArrowError.badInput("give at most one of --window, --region, --display") }
        if let window {
            return .window(try WindowLookup.windowNumber(try WindowQuery(window)), shadow: windowShadow)
        }
        if let region { return .region(try NumberListParser.rect(region)) }
        if let display {
            guard display >= 1 else { throw BigArrowError.badInput("--display counts from 1") }
            return .display(display)
        }
        return .display(1)
    }
}

struct CaptureResult: Codable {
    var ok = true
    let output: String
}
