#if os(Linux)
import ArgumentParser
import BigArrowCore

/// `capture` needs macOS's window list and `screencapture`; on Linux it says how to get the
/// screenshot instead, so scripts written for the Mac fail with a clear message.
struct CaptureCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "capture",
        abstract: "macOS only. On Linux take the screenshot another way, then use annotate."
    )

    @Argument(parsing: .allUnrecognized)
    var ignored: [String] = []

    func run() throws {
        throw BigArrowError.badInput("""
        capture needs macOS. Take the screenshot another way (agent-browser screenshot, \
        browser-director, gnome-screenshot), then: arrowshot annotate shot.png -o out.png --rect x,y,w,h --text "1. Click Save"
        """)
    }
}
#endif
