import ArgumentParser
import BigArrowCore
import Foundation

@main
struct ArrowShot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "arrowshot",
        abstract: "Bake a big arrow with a sign into a screenshot. Nothing is drawn on the screen.",
        discussion: """
        Coordinates are pixels of the image, top-left origin. Run a command again on its own \
        output for a second arrow. Exit codes: 0 ok, 2 bad input, 3 target unresolvable, \
        4 permission missing.
        """,
        version: "arrowshot \(BigArrowVersion.current)",
        subcommands: [AnnotateCommand.self, CaptureCommand.self]
    )

    /// Maps every failure onto the documented exit codes; argument errors are bad input (2).
    static func main() {
        let wantsJSON = CommandLine.arguments.contains("--json")
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let error as BigArrowError {
            Output.fail(error, json: wantsJSON)
        } catch {
            if exitCode(for: error) == .success { exit(withError: error) }
            Output.fail(.badInput(fullMessage(for: error)), json: wantsJSON)
        }
    }
}
