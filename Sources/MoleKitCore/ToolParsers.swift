import Foundation

// Previews (`--dry-run`) of the interactive Mole tools, formats of mo 1.71.

/// `mo uninstall --dry-run <name>`: what goes and which personal data stays.
public struct UninstallPreview: Sendable, Equatable {
    public struct File: Sendable, Equatable, Identifiable {
        public let path: String
        public let bytes: Int64?
        public var id: String { path }
    }
    public let remove: [File]
    public let keep: [String]
    public var totalBytes: Int64 { remove.compactMap(\.bytes).reduce(0, +) }

    public static func parse(_ stdout: String) -> UninstallPreview {
        enum Part { case none, remove, keep }
        var part = Part.none
        var remove: [File] = [], keep: [String] = []
        for raw in stdout.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Files to be removed") { part = .remove; continue }
            if line.hasPrefix("Personal data kept") || line.hasPrefix("Personal data") { part = .keep; continue }
            switch part {
            case .remove:
                if let m = Rx.match(#"^✓\s*(\S.*?)\s*,\s*([0-9.]+\s*(?:B|KB|MB|GB|TB))\s*$"#, line) {
                    remove.append(File(path: m[1] ?? "", bytes: ByteSize.parse(m[2] ?? "")))
                } else if let m = Rx.match(#"^✓\s*(/.+|~/.+)$"#, line) {
                    remove.append(File(path: m[1] ?? "", bytes: nil))
                }
            case .keep:
                if let m = Rx.match(#"^⊙\s*(.+)$"#, line) { keep.append(m[1] ?? "") }
            case .none: break
            }
        }
        return UninstallPreview(remove: remove, keep: keep)
    }
}

/// `mo slim --dry-run`: apps and how much Intel code each carries.
public struct SlimPreview: Sendable, Equatable {
    public struct App: Sendable, Equatable, Identifiable {
        public let name: String
        public let bytes: Int64
        public var id: String { name }
    }
    public let apps: [App]
    public let reportedTotal: Int64?
    public var total: Int64 { reportedTotal ?? apps.reduce(0) { $0 + $1.bytes } }

    public static func parse(_ stdout: String) -> SlimPreview {
        var apps: [App] = []
        var total: Int64?
        for raw in stdout.split(separator: "\n") {
            let line = String(raw)
            if let m = Rx.match(#"^\s*[0-9]+\s+apps?,\s*([0-9.]+\s*(?:B|KB|MB|GB|TB))\s+of Intel code"#, line) {
                total = ByteSize.parse(m[1] ?? "")
            } else if let m = Rx.match(#"^\s{2,}(\S.*?)\s{2,}([0-9.]+\s*(?:B|KB|MB|GB|TB))\s*$"#, line) {
                apps.append(App(name: m[1] ?? "", bytes: ByteSize.parse(m[2] ?? "") ?? 0))
            }
        }
        return SlimPreview(apps: apps, reportedTotal: total)
    }
}

/// `mo optimize --dry-run`: maintenance steps grouped by section.
public struct OptimizePreview: Sendable, Equatable {
    public struct Step: Sendable, Equatable, Identifiable {
        public let section: String
        public let lines: [String]
        /// Mole marks things that need attention with ◎.
        public let needsAttention: Bool
        public var id: String { section }
    }
    public let steps: [Step]

    public static func parse(_ stdout: String) -> OptimizePreview {
        var steps: [Step] = []
        var section: String?
        var lines: [String] = []
        var attention = false
        func close() {
            if let section { steps.append(Step(section: section, lines: lines, needsAttention: attention)) }
            lines = []; attention = false
        }
        for raw in stdout.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("➤") {
                close()
                section = line.dropFirst().trimmingCharacters(in: .whitespaces)
            } else if section != nil, let m = Rx.match(#"^([○◎✓⊙])\s*(.+)$"#, line) {
                if m[1] == "◎" { attention = true }
                lines.append(m[2] ?? "")
            }
        }
        close()
        return OptimizePreview(steps: steps)
    }
}

/// `mo installer --dry-run`: installer files found (or none).
public struct InstallerPreview: Sendable, Equatable {
    public struct File: Sendable, Equatable, Identifiable {
        public let path: String
        public let bytes: Int64?
        public var id: String { path }
    }
    public let files: [File]
    public let nothingFound: Bool

    public static func parse(_ stdout: String) -> InstallerPreview {
        var files: [File] = []
        for raw in stdout.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let m = Rx.match(#"(~?/\S.*?\.(?:dmg|pkg|iso|xip|zip))\b.*?([0-9.]+\s*(?:B|KB|MB|GB|TB))?\s*$"#, line) {
                files.append(File(path: m[1] ?? "", bytes: m[2].flatMap { ByteSize.parse($0) }))
            }
        }
        return InstallerPreview(files: files, nothingFound: stdout.contains("No installer files"))
    }
}
