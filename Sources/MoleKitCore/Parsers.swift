import Foundation

// Parsers for the plain-text parts of Mole. They match the formats of mo 1.71
// and are covered by tests in Tests/MolekitTests.

/// Mole prints sizes in decimal units (1 GB = 1,000,000,000 bytes), see `bytes_to_human` in Mole.
public enum ByteSize {
    private static let units: [String: Double] = ["B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12]

    /// "16.27GB" → 16270000000. Returns nil for anything else.
    public static func parse(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let match = Rx.match(#"^([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB|TB)$"#, trimmed) else { return nil }
        guard let value = Double(match[1] ?? ""), let factor = units[match[2] ?? ""] else { return nil }
        return Int64((value * factor).rounded())
    }

    /// Bytes → "12.4 GB" / "12,4 ГБ" in the given language, decimal units like Mole.
    public static func format(_ bytes: Int64, language: String = "en", fractionDigits: Int? = nil) -> String {
        let uk = language == "uk"
        let names = uk ? ["Б", "КБ", "МБ", "ГБ", "ТБ"] : ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes), index = 0
        while value >= 1000, index < names.count - 1 { value /= 1000; index += 1 }
        let digits = fractionDigits ?? (index == 0 ? 0 : (value >= 100 ? 0 : 1))
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: uk ? "uk_UA" : "en_US")
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        let number = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
        return "\(number) \(names[index])"
    }
}

// MARK: - clean preview (~/.config/mole/clean-list.txt)

/// What `mo clean --dry-run` found, grouped by Mole's own sections.
public struct CleanPreview: Sendable {
    public struct Item: Sendable, Identifiable, Hashable {
        public let path: String
        public let bytes: Int64
        public let count: Int?
        public var id: String { path }
    }
    public struct Section: Sendable, Identifiable {
        public let title: String
        public let items: [Item]
        public var id: String { title }
        public var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    }
    public let sections: [Section]
    /// Mole's own total from the summary block, when present.
    public let reportedTotal: Int64?
    public let reportedItems: Int?

    public var nonEmptySections: [Section] { sections.filter { !$0.items.isEmpty } }
    public var total: Int64 { reportedTotal ?? sections.reduce(0) { $0 + $1.bytes } }
}

public enum CleanListParser {
    public static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/mole/clean-list.txt")
    }

    public static func parse(_ text: String) -> CleanPreview {
        var sections: [CleanPreview.Section] = []
        var title: String?
        var items: [CleanPreview.Item] = []
        var total: Int64?
        var count: Int?

        func close() {
            if let title { sections.append(.init(title: title, items: items)) }
            items = []
        }

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let m = Rx.match(#"^===\s*(.+?)\s*===$"#, line) {
                close()
                title = (m[1] ?? "")
            } else if let m = Rx.match(#"^#\s*Potential cleanup:\s*(\S+)"#, line) {
                total = ByteSize.parse((m[1] ?? ""))
            } else if let m = Rx.match(#"^#\s*Items:\s*([0-9]+)"#, line) {
                count = Int(m[1] ?? "")
            } else if line.hasPrefix("#") || line.isEmpty {
                continue
            } else if title != nil,
                      let m = Rx.match(#"^(.+?)\s+#\s+([0-9.]+\s*(?:B|KB|MB|GB|TB))(?:,\s*([0-9]+)\s+items?)?\s*$"#, line) {
                items.append(.init(path: (m[1] ?? ""),
                                   bytes: ByteSize.parse((m[2] ?? "")) ?? 0,
                                   count: m[3].flatMap { Int($0) }))
            }
        }
        close()
        return CleanPreview(sections: sections, reportedTotal: total, reportedItems: count)
    }
}

// MARK: - summaries printed by mo clean

public struct RunSummary: Sendable, Equatable {
    public let bytes: Int64
    public let items: Int?
}

public enum SummaryParser {
    /// Reads "Removed: 12.26GB · 2397 items" or "Potential space: 12.38GB · 2622 items".
    public static func clean(_ stdout: String) -> RunSummary? {
        guard let m = Rx.match(#"(?:Removed|Potential space|Freed):\s*([0-9.]+\s*(?:B|KB|MB|GB|TB))(?:\s*·\s*([0-9]+)\s+items?)?"#, stdout) else { return nil }
        return RunSummary(bytes: ByteSize.parse((m[1] ?? "")) ?? 0, items: m[2].flatMap { Int($0) })
    }
}

// MARK: - purge preview (mo purge --dry-run)

public struct PurgePreview: Sendable {
    public struct Item: Sendable, Identifiable, Hashable {
        public let path: String
        public let bytes: Int64
        public var id: String { path }
        /// The kind of build output, from the folder name.
        public var kind: String {
            let last = (path as NSString).lastPathComponent
            switch last {
            case "node_modules": return "node_modules"
            case ".venv", "venv": return "Python venv"
            case "__pycache__": return "Python cache"
            case ".build": return "Swift build"
            case ".gradle": return "Gradle"
            case "build": return "build"
            case "dist": return "dist"
            case "target": return "target"
            default: return last
            }
        }
        /// Deleting a virtualenv means reinstalling dependencies by hand.
        public var needsManualRestore: Bool { kind == "Python venv" }
    }
    public let items: [Item]
    public let reportedTotal: Int64?
    public var total: Int64 { reportedTotal ?? items.reduce(0) { $0 + $1.bytes } }
}

public enum PurgeParser {
    public static func parse(_ stdout: String) -> PurgePreview {
        var items: [PurgePreview.Item] = []
        var total: Int64?
        for raw in stdout.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let m = Rx.match(#"(?:\[DRY RUN\]\s*)?(~?\/.+),\s*([0-9.]+\s*(?:B|KB|MB|GB|TB))\s*$"#, line) {
                items.append(.init(path: (m[1] ?? ""), bytes: ByteSize.parse((m[2] ?? "")) ?? 0))
            } else if let m = Rx.match(#"Would free approximately:\s*([0-9.]+\s*(?:B|KB|MB|GB|TB))"#, line) {
                total = ByteSize.parse((m[1] ?? ""))
            }
        }
        return PurgePreview(items: items, reportedTotal: total)
    }
}

// MARK: - helpers

public enum PathDisplay {
    /// "/Users/someone/Library/Caches" → "~/Library/Caches".
    public static func tilde(_ path: String, home: String = NSHomeDirectory()) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

/// Small regex helper: returns capture groups (index 0 = whole match), nil when no match.
enum Rx {
    static func match(_ pattern: String, _ text: String) -> [String?]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            guard r.location != NSNotFound, let sr = Range(r, in: text) else { return nil }
            return String(text[sr])
        }
    }
}
