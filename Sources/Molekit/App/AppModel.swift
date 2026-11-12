import SwiftUI
import AppKit
import MoleKitCore

/// Screens inside Tools.
enum ToolScreen { case purge, uninstall, optimize, slim, installer }

enum Tab: Int, CaseIterable, Identifiable {
    case clean, overview, tools, disk, status, history
    var id: Int { rawValue }
    var key: String { ["nav.clean", "nav.overview", "nav.tools", "nav.disk", "nav.status", "nav.history"][rawValue] }
    var symbol: String { ["sparkles", "chart.bar.fill", "briefcase.fill", "internaldrive.fill", "waveform.path.ecg", "clock.arrow.circlepath"][rawValue] }
}

/// Root state shared by all screens.
@MainActor
final class AppModel: ObservableObject {
    @Published var tab: Tab = .clean
    @Published var toolScreen: ToolScreen?
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    let cli: MoleCLI?
    let clean: CleanModel
    let status: StatusModel
    let history: HistoryModel
    let disk: DiskModel
    let purge: PurgeModel
    let tools: ToolsModel
    let updates: UpdateModel

    init() {
        let saved = UserDefaults.standard.string(forKey: "language").flatMap(AppLanguage.init(rawValue:))
        language = saved ?? .systemDefault
        cli = MoleCLI.locate()
        clean = CleanModel(cli: cli)
        status = StatusModel(cli: cli)
        history = HistoryModel(cli: cli)
        disk = DiskModel(cli: cli)
        purge = PurgeModel(cli: cli)
        tools = ToolsModel(cli: cli)
        updates = UpdateModel(cli: cli)
        // If the app quit in the middle of a run, put Mole's whitelist back first.
        try? WhitelistSession().restore()
    }

    func t(_ key: String) -> String { language.string(key) }
    func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: language.string(key), locale: Locale(identifier: language == .uk ? "uk_UA" : "en_US"), arguments: args)
    }
    func size(_ bytes: Int64) -> String { ByteSize.format(bytes, language: language.rawValue) }
    var langCode: String { language.rawValue }
}

/// Free space as Finder shows it (includes purgeable space macOS can reclaim).
enum DiskSpace {
    static func root() -> (free: Int64, total: Int64)? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else { return nil }
        return (free, Int64(total))
    }
}

// MARK: - Clean

@MainActor
final class CleanModel: ObservableObject {
    enum Phase: Equatable { case idle, scanning, found, cleaning, done, failed(String) }

    @Published var phase: Phase = .idle
    @Published var progress: Double = 0
    @Published var currentSection = ""
    @Published var preview: CleanPreview?
    @Published var deselected: Set<String> = []
    @Published var result: RunSummary?
    @Published var expanded: Set<String> = []
    @Published var sectionsSeen = 0
    /// Categories as `mo clean --dry-run` prints them, filled in live while scanning.
    @Published var live: [LiveSection] = []
    struct LiveSection: Identifiable, Equatable {
        let title: String
        var bytes: Int64 = 0
        var finds = 0
        var id: String { title }
    }
    var liveTotal: Int64 { live.reduce(0) { $0 + $1.bytes } }

    private let cli: MoleCLI?
    private var task: Task<Void, Never>?
    /// Mole prints one "➤ Section" header per category; used as a progress estimate.
    private var expectedSections = 18

    init(cli: MoleCLI?) { self.cli = cli }

    var sections: [CleanPreview.Section] { preview?.nonEmptySections ?? [] }
    /// Categories Mole checked and found nothing in.
    var cleanSections: [CleanPreview.Section] { (preview?.sections ?? []).filter { $0.items.isEmpty } }
    var selectedSections: [CleanPreview.Section] { sections.filter { !deselected.contains($0.title) } }
    var selectedBytes: Int64 { selectedSections.reduce(0) { $0 + $1.bytes } }
    var allSelected: Bool { deselected.isEmpty }
    var isBusy: Bool { phase == .scanning || phase == .cleaning }

    func toggle(_ title: String) {
        if deselected.contains(title) { deselected.remove(title) } else { deselected.insert(title) }
    }

    func toggleAll() {
        deselected = allSelected ? Set(sections.map(\.title)) : []
    }

    /// `mo clean --dry-run`, then read the detailed list Mole writes.
    func scan() {
        guard let cli, !isBusy else { return }
        phase = .scanning; progress = 0; sectionsSeen = 0; currentSection = ""; result = nil; live = []
        task = Task {
            do {
                for try await line in cli.lines(["clean", "--dry-run"]) {
                    handleProgress(line)
                }
                try Task.checkCancellation()
                let text = try String(contentsOf: CleanListParser.defaultURL, encoding: .utf8)
                let parsed = CleanListParser.parse(text)
                expectedSections = max(parsed.sections.count, 1)
                preview = parsed
                deselected = deselected.intersection(Set(parsed.nonEmptySections.map(\.title)))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { progress = 1 }
                phase = .found
            } catch is CancellationError {
                phase = preview == nil ? .idle : .found
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// `mo clean`. Unticked categories are protected for this one run via Mole's whitelist.
    func cleanSelected() {
        guard let cli, phase == .found, !selectedSections.isEmpty else { return }
        phase = .cleaning; progress = 0; sectionsSeen = 0
        let protect = sections.filter { deselected.contains($0.title) }.flatMap { $0.items.map(\.path) }
        task = Task {
            let session = WhitelistSession()
            var output = ""
            do {
                if !protect.isEmpty {
                    guard let defaults = await cli.defaultWhitelist() else {
                        phase = .failed("Could not read Mole's default whitelist, so unticked categories cannot be protected safely. Tick everything or clean in Terminal.")
                        return
                    }
                    try session.apply(paths: protect, defaults: defaults)
                }
                defer { try? session.restore() }
                for try await line in cli.lines(["clean"]) {
                    output += line + "\n"
                    handleProgress(line)
                }
                try? session.restore()
                result = SummaryParser.clean(output) ?? RunSummary(bytes: selectedBytes, items: nil)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { progress = 1 }
                phase = .done
            } catch is CancellationError {
                try? session.restore()
                phase = .found
            } catch {
                try? session.restore()
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if phase == .scanning { phase = preview == nil ? .idle : .found }
        if phase == .cleaning { phase = .found }
    }

    private func handleProgress(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if phase == .scanning, trimmed.hasPrefix("○") || trimmed.hasPrefix("◎"), !live.isEmpty,
           let bytes = LiveLine.size(trimmed) {
            withAnimation(.easeOut(duration: 0.25)) {
                live[live.count - 1].bytes += bytes
                live[live.count - 1].finds += 1
            }
            return
        }
        guard trimmed.hasPrefix("➤") else { return }
        sectionsSeen += 1
        currentSection = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        if phase == .scanning {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { live.append(LiveSection(title: currentSection)) }
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            progress = min(0.97, Double(sectionsSeen) / Double(expectedSections))
        }
    }
}

// MARK: - Status (live)

@MainActor
final class StatusModel: ObservableObject {
    @Published var snapshot: StatusSnapshot?
    @Published var error: String?
    private let cli: MoleCLI?
    private var task: Task<Void, Never>?

    init(cli: MoleCLI?) { self.cli = cli }

    func refreshOnce() {
        guard let cli else { return }
        Task {
            do {
                let out = try await cli.runChecked(["status", "--json"])
                snapshot = try MoleJSON.decode(StatusSnapshot.self, from: out.stdout)
            } catch { self.error = error.localizedDescription }
        }
    }

    func startLive() {
        guard let cli, task == nil else { return }
        task = Task {
            do {
                for try await line in cli.lines(["status", "--watch", "--interval", "1s"]) {
                    if let s = try? MoleJSON.decode(StatusSnapshot.self, from: line) { snapshot = s }
                }
            } catch { self.error = error.localizedDescription }
            task = nil
        }
    }

    func stopLive() { task?.cancel(); task = nil }
}

// MARK: - History

@MainActor
final class HistoryModel: ObservableObject {
    @Published var sessions: [HistoryResult.Session] = []
    @Published var loading = false
    private let cli: MoleCLI?
    init(cli: MoleCLI?) { self.cli = cli }

    func load() {
        guard let cli else { return }
        loading = true
        Task {
            if let out = try? await cli.runChecked(["history", "--json", "--limit", "50"]),
               let h = try? MoleJSON.decode(HistoryResult.self, from: out.stdout) {
                sessions = h.sessions ?? []
            }
            loading = false
        }
    }

    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: s)
    }

    var today: [HistoryResult.Session] {
        sessions.filter { Self.date($0.startedAt).map(Calendar.current.isDateInToday) ?? false }
    }
    var lastRealClean: HistoryResult.Session? {
        sessions.first { $0.baseCommand == "clean" && !$0.isPreview }
    }
}

// MARK: - Disk

/// One level of `mo analyze --json [path]`: folders sorted by size, plus the biggest files.
@MainActor
final class DiskModel: ObservableObject {
    struct Level {
        let path: String?            // nil = machine-wide overview
        let title: String
        var entries: [AnalyzeResult.Entry]
        var largeFiles: [AnalyzeResult.LargeFile]
        var total: Int64 { entries.reduce(0) { $0 + $1.size } }
    }
    @Published var stack: [Level] = []
    @Published var loading = false
    @Published var error: String?
    private let cli: MoleCLI?
    private var task: Task<Void, Never>?

    init(cli: MoleCLI?) { self.cli = cli }

    var current: Level? { stack.last }

    func loadRoot() {
        stack = []
        open(path: nil, title: "Macintosh HD")
    }

    func open(path: String?, title: String) {
        guard let cli else { return }
        task?.cancel()
        loading = true; error = nil
        task = Task {
            do {
                var args = ["analyze", "--json"]
                if let path { args.append(path) }
                let out = try await cli.runChecked(args)
                try Task.checkCancellation()
                let r = try MoleJSON.decode(AnalyzeResult.self, from: out.stdout)
                let entries = (r.entries ?? []).filter { $0.size > 0 }.sorted { $0.size > $1.size }
                stack.append(Level(path: path, title: title, entries: entries,
                                   largeFiles: Array((r.largeFiles ?? []).sorted { $0.size > $1.size }.prefix(6))))
                loading = false
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
                loading = false
            }
        }
    }

    func back() {
        task?.cancel(); loading = false
        if stack.count > 1 { stack.removeLast() }
    }

    func jump(to index: Int) {
        task?.cancel(); loading = false
        if index < stack.count - 1 { stack.removeLast(stack.count - 1 - index) }
    }
}

// MARK: - Purge (project build output)

@MainActor
final class PurgeModel: ObservableObject {
    enum Phase: Equatable { case idle, scanning, ready, running, done, failed(String) }
    @Published var phase: Phase = .idle
    @Published var preview: PurgePreview?
    @Published var deselected: Set<String> = []
    @Published var freed: Int64 = 0
    private let cli: MoleCLI?
    init(cli: MoleCLI?) { self.cli = cli }

    var items: [PurgePreview.Item] { preview?.items ?? [] }
    var selectedBytes: Int64 { items.filter { !deselected.contains($0.path) }.reduce(0) { $0 + $1.bytes } }

    func scan() {
        guard let cli else { return }
        phase = .scanning
        Task {
            do {
                let out = try await cli.run(["purge", "--dry-run"])
                preview = PurgeParser.parse(out.stdout)
                // Virtual environments need a manual reinstall: leave them unticked by default.
                deselected = Set(items.filter(\.needsManualRestore).map(\.path))
                phase = .ready
            } catch { phase = .failed(error.localizedDescription) }
        }
    }

    func toggle(_ path: String) {
        if deselected.contains(path) { deselected.remove(path) } else { deselected.insert(path) }
    }

    func run() {
        guard let cli, phase == .ready else { return }
        phase = .running
        let home = NSHomeDirectory()
        let protect = items.filter { deselected.contains($0.path) }
            .map { $0.path.hasPrefix("~") ? home + $0.path.dropFirst() : $0.path }
        let expected = selectedBytes
        Task {
            let session = WhitelistSession()
            do {
                if !protect.isEmpty {
                    guard let defaults = await cli.defaultWhitelist() else {
                        phase = .failed("Could not read Mole's default whitelist; untick nothing or run mo purge in Terminal.")
                        return
                    }
                    try session.apply(paths: protect, defaults: defaults)
                }
                _ = try await cli.run(["purge", "--yes"])
                try? session.restore()
                freed = expected
                phase = .done
            } catch {
                try? session.restore()
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Tools

/// Previews for the interactive Mole tools. The final step of uninstall / slim / installer
/// runs inside an in-app terminal, where Mole asks for its own confirmation.
@MainActor
final class ToolsModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var appsLoading = false
    @Published var selectedApp: InstalledApp?
    @Published var uninstallPreview: UninstallPreview?
    @Published var previewLoading = false
    @Published var slim: SlimPreview?
    @Published var optimize: OptimizePreview?
    @Published var installer: InstallerPreview?
    @Published var loading: Set<String> = []
    let cli: MoleCLI?
    init(cli: MoleCLI?) { self.cli = cli }

    var appCount: Int? { apps.isEmpty ? nil : apps.count }

    func load() {
        guard let cli, apps.isEmpty, !appsLoading else { return }
        appsLoading = true
        Task {
            if let out = try? await cli.runChecked(["uninstall", "--list"]),
               let list = try? MoleJSON.decode([InstalledApp].self, from: out.stdout) {
                apps = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            appsLoading = false
        }
    }

    func select(_ app: InstalledApp) {
        guard let cli else { return }
        selectedApp = app
        uninstallPreview = nil
        previewLoading = true
        Task {
            let out = try? await cli.run(["uninstall", "--dry-run", app.uninstallName ?? app.name])
            guard selectedApp == app else { return }
            uninstallPreview = out.map { UninstallPreview.parse($0.stdout) }
            previewLoading = false
        }
    }

    func loadSlim(force: Bool = false) {
        run("slim", ["slim", "--dry-run"], force: force || slim == nil) { self.slim = SlimPreview.parse($0) }
    }
    func loadOptimize(force: Bool = false) {
        run("optimize", ["optimize", "--dry-run"], force: force || optimize == nil) { self.optimize = OptimizePreview.parse($0) }
    }
    func loadInstaller(force: Bool = false) {
        run("installer", ["installer", "--dry-run"], force: force || installer == nil) { self.installer = InstallerPreview.parse($0) }
    }

    private func run(_ key: String, _ args: [String], force: Bool, apply: @escaping (String) -> Void) {
        guard let cli, force, !loading.contains(key) else { return }
        loading.insert(key)
        Task {
            if let out = try? await cli.run(args) { apply(out.stdout) }
            loading.remove(key)
        }
    }

    /// Used when an update fails.
    func openInTerminal(_ command: String) {
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(command)\"\nend tell"
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }
}

// MARK: - Mole updates

@MainActor
final class UpdateModel: ObservableObject {
    enum State: Equatable { case checking, upToDate, available(String), updating, failed, offline }
    @Published var installed: String?
    @Published var state: State = .checking
    private let cli: MoleCLI?
    init(cli: MoleCLI?) { self.cli = cli }

    var channel: MoleUpdate.Channel { cli.map(MoleUpdate.channel(of:)) ?? .homebrew }

    func check() {
        guard let cli else { return }
        state = .checking
        Task {
            installed = await MoleUpdate.installedVersion(cli)
            guard let latest = await MoleUpdate.latestVersion(channel: channel) else { state = .offline; return }
            if let installed, MoleUpdate.isNewer(latest, than: installed) {
                state = .available(latest)
            } else {
                state = .upToDate
            }
        }
    }

    /// `mo update` (Homebrew installs run brew upgrade under the hood).
    func update() {
        guard let cli else { return }
        state = .updating
        Task {
            let out = try? await cli.run(["update"])
            if out?.status == 0 { check() } else { state = .failed }
        }
    }
}

/// Reads the size from a live `mo clean --dry-run` line such as
/// "○ Firefox cache · 843.6MB dry" or "○ Chrome Service Worker, would clean 215.1MB, 0 protected".
enum LiveLine {
    static func size(_ line: String) -> Int64? {
        guard let re = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?\s*(?:B|KB|MB|GB|TB))(?=\s+dry|,|\s*$)"#),
              let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let r = Range(m.range(at: 1), in: line) else { return nil }
        return ByteSize.parse(String(line[r]))
    }
}
