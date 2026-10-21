#if os(macOS)
import AppKit
import BigArrowCore
import BigArrowTargeting
import Foundation

/// Runs macOS `screencapture` silently (`-x`, no sound) into a PNG.
enum Screencapture {
    enum Source {
        case window(CGWindowID, shadow: Bool)
        case region(CGRect)
        case display(Int)
    }

    static func run(_ source: Source, to url: URL) throws {
        var arguments = ["-x", "-t", "png"]
        switch source {
        case .window(let id, let shadow):
            arguments += shadow ? ["-l", String(id)] : ["-o", "-l", String(id)]
        case .region(let rect):
            let numbers = [rect.minX, rect.minY, rect.width, rect.height].map { String(format: "%g", $0) }
            arguments += ["-R", numbers.joined(separator: ",")]
        case .display(let index):
            arguments += ["-D", String(index)]
        }
        try? FileManager.default.removeItem(at: url)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments + [url.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) else {
            throw BigArrowError.unresolvable("screencapture \(arguments.joined(separator: " ")) failed (status \(process.terminationStatus))")
        }
    }
}

/// Finds the CGWindowID of an app's frontmost visible window, optionally by title.
@MainActor
enum WindowLookup {
    static func windowNumber(_ query: WindowQuery) throws -> CGWindowID {
        let apps = WindowTarget.runningApps()
        let matched = WindowMatcher.apps(matching: query.app, in: apps)
        guard !matched.isEmpty else {
            let names = WindowMatcher.appsWithWindows(apps, WindowTarget.onScreenWindows()).joined(separator: ", ")
            throw BigArrowError.unresolvable("no running app matches '\(query.app)'; apps with windows: \(names)")
        }
        let pids = Set(matched.map(\.pid))
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let found = list.first { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? Int32, pids.contains(pid),
                  (entry[kCGWindowLayer as String] as? Int ?? 0) == 0,
                  let bounds = (entry[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0) }),
                  bounds.width >= 40, bounds.height >= 40 else { return false }
            guard let title = query.title else { return true }
            return (entry[kCGWindowName as String] as? String)?.localizedCaseInsensitiveContains(title) ?? false
        }
        guard let number = found?[kCGWindowNumber as String] as? UInt32 else {
            let what = query.title.map { "no window titled '*\($0)*'" } ?? "no visible window"
            throw BigArrowError.unresolvable("\(matched[0].name ?? query.app) has \(what) on screen")
        }
        return CGWindowID(number)
    }
}
#endif
