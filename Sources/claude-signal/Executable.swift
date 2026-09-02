import Foundation

enum Executable {
    /// Absolute path of this binary. Prefers the PATH-visible location
    /// (e.g. the stable Homebrew symlink) over the physical path, which
    /// changes on every versioned upgrade.
    static func currentPath() -> String {
        let argv0 = CommandLine.arguments[0]
        if argv0.contains("/") {
            return URL(fileURLWithPath: argv0).standardizedFileURL.path
        }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = "\(directory)/\(argv0)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return Bundle.main.executablePath ?? argv0
    }
}
