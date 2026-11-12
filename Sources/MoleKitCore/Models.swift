import Foundation

// JSON models for `mo ... --json`. Every field is optional on purpose:
// Mole is actively developed, and a missing or renamed field must not crash the app.

// MARK: - mo status --json

public struct StatusSnapshot: Decodable, Sendable {
    public struct Hardware: Decodable, Sendable {
        public let model: String?
        public let cpuModel: String?
        public let totalRam: String?
        public let diskSize: String?
        public let osVersion: String?
    }
    public struct CPU: Decodable, Sendable {
        public let usage: Double?
        public let perCore: [Double]?
        public let load1: Double?
        public let coreCount: Int?
        public let pCoreCount: Int?
        public let eCoreCount: Int?
    }
    public struct Memory: Decodable, Sendable {
        public let used: Int64?
        public let total: Int64?
        public let usedPercent: Double?
        public let swapUsed: Int64?
        public let swapTotal: Int64?
        public let pressure: String?
    }
    public struct Disk: Decodable, Sendable {
        public let mount: String?
        public let used: Int64?
        public let total: Int64?
        public let usedPercent: Double?
        public let external: Bool?
        public let smartStatus: String?
    }
    public struct Battery: Decodable, Sendable {
        public let percent: Double?
        public let status: String?
        public let timeLeft: String?
        public let health: String?
        public let cycleCount: Int?
    }
    public struct Process: Decodable, Sendable, Identifiable {
        public let pid: Int?
        public let name: String?
        public let cpu: Double?
        public let memoryBytes: Int64?
        public var id: String { "\(pid ?? 0)-\(name ?? "")" }
    }

    public let collectedAt: String?
    public let uptime: String?
    public let hardware: Hardware?
    public let healthScore: Int?
    public let healthScoreMsg: String?
    public let cpu: CPU?
    public let memory: Memory?
    public let disks: [Disk]?
    public let batteries: [Battery]?
    public let topProcesses: [Process]?
    public let trashSize: Int64?

    /// The startup volume ("/").
    public var rootDisk: Disk? { disks?.first(where: { $0.mount == "/" }) ?? disks?.first }
}

// MARK: - mo analyze --json [path]

public struct AnalyzeResult: Decodable, Sendable {
    public struct Entry: Decodable, Sendable, Identifiable, Hashable {
        public let name: String
        public let path: String
        public let size: Int64
        public let isDir: Bool?
        public let scanStatus: String?
        public var id: String { path }
    }
    public let scanStatus: String?
    public let path: String?
    public let overview: Bool?
    public let entries: [Entry]?
    public let totalSize: Int64?
}

// MARK: - mo history --json

public struct HistoryResult: Decodable, Sendable {
    public struct Session: Decodable, Sendable, Identifiable {
        public struct Actions: Decodable, Sendable {
            public let removed: Int?
            public let trashed: Int?
            public let skipped: Int?
            public let failed: Int?
        }
        public let command: String
        public let runId: String?
        public let startedAt: String?
        public let endedAt: String?
        public let items: Int?
        public let size: String?
        public let failedTasks: Int?
        public let actions: Actions?

        public var id: String { "\(startedAt ?? "")-\(command)-\(runId ?? "")" }
        /// A preview (`--dry-run`) touched nothing on disk.
        public var isPreview: Bool {
            if command.hasSuffix("dry-run") { return true }
            let a = actions
            return (a?.removed ?? 0) == 0 && (a?.trashed ?? 0) == 0
        }
        public var sizeBytes: Int64 { ByteSize.parse(size ?? "") ?? 0 }
        public var baseCommand: String { command.replacingOccurrences(of: "-dry-run", with: "") }
    }
    public let sessions: [Session]?
}

// MARK: - mo uninstall --list

public struct InstalledApp: Decodable, Sendable, Identifiable, Hashable {
    public let name: String
    public let bundleId: String?
    public let source: String?
    public let uninstallName: String?
    public let path: String?
    public var id: String { bundleId ?? path ?? name }
}

// MARK: - Decoding helper

public enum MoleJSON {
    public static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // `mo` may print a line or two before the JSON; start at the first brace or bracket.
        let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }) ?? text.startIndex
        return try decoder.decode(T.self, from: Data(text[start...].utf8))
    }
}
