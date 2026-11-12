import Foundation

/// Finds and runs the `mo` executable. Molekit never deletes anything itself:
/// every action is a `mo` command, so Mole's own safety rules always apply.
public struct MoleCLI: Sendable {
    public let executable: URL

    public enum Failure: Error, LocalizedError {
        case notInstalled
        case exited(code: Int32, stderr: String)

        public var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "Mole (mo) was not found. Install it with: brew install mole"
            case let .exited(code, stderr):
                return "mo exited with code \(code): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        }
    }

    public struct Output: Sendable {
        public let stdout: String
        public let stderr: String
        public let status: Int32
    }

    /// Places Homebrew and the official installer put `mo`. GUI apps do not inherit the shell PATH,
    /// so we look in the usual spots ourselves.
    public static let candidatePaths = [
        "/opt/homebrew/bin/mo",
        "/usr/local/bin/mo",
        "\(NSHomeDirectory())/.local/bin/mo"
    ]

    public init(executable: URL) {
        self.executable = executable
    }

    /// Returns nil when `mo` is not installed.
    public static func locate(fileManager: FileManager = .default) -> MoleCLI? {
        for path in candidatePaths where fileManager.isExecutableFile(atPath: path) {
            return MoleCLI(executable: URL(fileURLWithPath: path))
        }
        return nil
    }

    /// Environment for every run: no colours, no interactive terminal tricks.
    static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        env["TERM"] = "dumb"
        let extra = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = env["PATH"].map { "\(extra):\($0)" } ?? extra
        return env
    }

    /// Runs `mo` with arguments and returns everything it printed.
    public func run(_ arguments: [String]) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.environment = Self.environment()
            process.standardInput = FileHandle.nullDevice
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err

            // Read both pipes concurrently so a full buffer never blocks `mo`.
            let group = DispatchGroup()
            let outBox = DataBox(), errBox = DataBox()
            group.enter()
            DispatchQueue.global().async {
                outBox.data = out.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                errBox.data = err.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            process.terminationHandler = { proc in
                group.wait()
                continuation.resume(returning: Output(
                    stdout: ANSI.strip(String(decoding: outBox.data, as: UTF8.self)),
                    stderr: ANSI.strip(String(decoding: errBox.data, as: UTF8.self)),
                    status: proc.terminationStatus
                ))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Runs `mo` and throws when it exits non-zero.
    public func runChecked(_ arguments: [String]) async throws -> Output {
        let output = try await run(arguments)
        guard output.status == 0 else {
            throw Failure.exited(code: output.status, stderr: output.stderr.isEmpty ? output.stdout : output.stderr)
        }
        return output
    }

    /// Streams stdout line by line (for `mo status --watch` and live progress).
    /// Cancelling the task terminates the process.
    public func lines(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.environment = Self.environment()
            process.standardInput = FileHandle.nullDevice
            let out = Pipe()
            process.standardOutput = out
            process.standardError = FileHandle.nullDevice

            let buffer = LineBuffer()
            out.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    if let rest = buffer.flush() { continuation.yield(rest) }
                    return
                }
                for line in buffer.append(data) { continuation.yield(ANSI.strip(line)) }
            }
            process.terminationHandler = { proc in
                out.fileHandleForReading.readabilityHandler = nil
                if let rest = buffer.flush() { continuation.yield(ANSI.strip(rest)) }
                if proc.terminationStatus == 0 || proc.terminationReason == .uncaughtSignal {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: Failure.exited(code: proc.terminationStatus, stderr: ""))
                }
            }
            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }
            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

/// Holds bytes read on a background queue; access is ordered by the DispatchGroup.
final class DataBox: @unchecked Sendable { var data = Data() }

/// Splits a byte stream into lines.
final class LineBuffer: @unchecked Sendable {
    private var pending = Data()
    private let lock = NSLock()

    func append(_ data: Data) -> [String] {
        lock.lock(); defer { lock.unlock() }
        pending.append(data)
        var lines: [String] = []
        while let range = pending.firstRange(of: Data([0x0A])) {
            let lineData = pending.subdata(in: pending.startIndex..<range.lowerBound)
            lines.append(String(decoding: lineData, as: UTF8.self))
            pending.removeSubrange(pending.startIndex..<range.upperBound)
        }
        return lines
    }

    func flush() -> String? {
        lock.lock(); defer { lock.unlock() }
        guard !pending.isEmpty else { return nil }
        let line = String(decoding: pending, as: UTF8.self)
        pending.removeAll()
        return line
    }
}

/// Removes terminal escape sequences, in case a `mo` version ignores NO_COLOR.
public enum ANSI {
    public static func strip(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r", with: "")
    }
}
