import Foundation

enum PathUtils {

    /// Shortens a path by replacing the home directory with ~
    static func shortened(_ path: String) -> String {
        guard let home = ProcessInfo.processInfo.environment["HOME"],
              path.hasPrefix(home) else {
            return path
        }
        return "~" + path.dropFirst(home.count)
    }

    /// Expands ~ in a path to the full home directory path
    static func expanded(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
