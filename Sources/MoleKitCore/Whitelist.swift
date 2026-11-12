import Foundation

/// Mole cleans everything a run finds; it has no per-category switch (`--select` was removed).
/// To let people untick a category, Molekit temporarily adds those paths to Mole's own
/// whitelist (~/.config/mole/whitelist) and puts the file back exactly as it was afterwards.
///
/// Mole's rules (lib/core/base.sh, app_protection.sh in mo 1.71):
/// - a whitelist file, when present, REPLACES Mole's convenience defaults, so when we create
///   the file we must write those defaults in too;
/// - a plain path protects itself and everything inside it.
public final class WhitelistSession {
    public let whitelistURL: URL
    public let stateURL: URL
    private let fileManager: FileManager

    private struct SavedState: Codable {
        let existed: Bool
        let original: String
    }

    public init(home: URL = URL(fileURLWithPath: NSHomeDirectory()),
                stateDirectory: URL? = nil,
                fileManager: FileManager = .default) {
        self.whitelistURL = home.appendingPathComponent(".config/mole/whitelist")
        let dir = stateDirectory ?? home.appendingPathComponent("Library/Application Support/Molekit")
        self.stateURL = dir.appendingPathComponent("whitelist-backup.json")
        self.fileManager = fileManager
    }

    public var hasPendingRestore: Bool { fileManager.fileExists(atPath: stateURL.path) }

    /// Adds `paths` for one run. `defaults` are Mole's default patterns, needed only
    /// when the user has no whitelist file yet. Call `restore()` when the run ends.
    public func apply(paths: [String], defaults: [String]) throws {
        guard !paths.isEmpty else { return }
        if hasPendingRestore { try restore() }

        let existed = fileManager.fileExists(atPath: whitelistURL.path)
        let original = existed ? try String(contentsOf: whitelistURL, encoding: .utf8) : ""

        try fileManager.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let state = try JSONEncoder().encode(SavedState(existed: existed, original: original))
        try state.write(to: stateURL, options: .atomic)

        var lines: [String] = []
        if existed {
            lines.append(original.hasSuffix("\n") || original.isEmpty ? String(original.dropLast(original.hasSuffix("\n") ? 1 : 0)) : original)
        } else {
            lines.append("# Mole defaults (written by Molekit for one run, removed afterwards)")
            lines.append(contentsOf: defaults)
        }
        lines.append("# Molekit: unticked in the app, temporary")
        lines.append(contentsOf: paths.filter(Self.isSafeEntry))
        try fileManager.createDirectory(at: whitelistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(to: whitelistURL, atomically: true, encoding: .utf8)
    }

    /// Puts the whitelist back exactly as it was before `apply`.
    public func restore() throws {
        guard hasPendingRestore else { return }
        let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: stateURL))
        if state.existed {
            try state.original.write(to: whitelistURL, atomically: true, encoding: .utf8)
        } else if fileManager.fileExists(atPath: whitelistURL.path) {
            try fileManager.removeItem(at: whitelistURL)
        }
        try fileManager.removeItem(at: stateURL)
    }

    /// Mole rejects relative paths, `..`, control characters and treats * ? [ as globs.
    static func isSafeEntry(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.contains("..") && !path.contains("//")
            && path.rangeOfCharacter(from: .controlCharacters) == nil
            && path.rangeOfCharacter(from: CharacterSet(charactersIn: "*?[")) == nil
    }
}

extension MoleCLI {
    /// Mole's default whitelist, read from Mole's own script so it always matches the installed version.
    /// Returns nil when it cannot be read; the app then does not allow unticking categories.
    public func defaultWhitelist() async -> [String]? {
        let resolved = executable.resolvingSymlinksInPath()
        let base = resolved.deletingLastPathComponent().appendingPathComponent("lib/core/base.sh")
        guard FileManager.default.fileExists(atPath: base.path) else { return nil }
        let script = "source \"$1\" >/dev/null 2>&1; printf '%s\\n' \"${DEFAULT_WHITELIST_PATTERNS[@]}\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script, "molekit", base.path]
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines
    }
}
