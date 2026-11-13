import SwiftUI
import AppKit
import MoleKitCore

/// `Molekit --demo-shots <folder>`: fills every screen with made-up data, saves a PNG of the
/// window for each screen, then quits. Used for README screenshots; no real files are shown.
enum DemoShots {
    static var folder: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo-shots"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }
    static var isActive: Bool { folder != nil }
    @MainActor private static var demoPreview: CleanPreview?

    @MainActor
    static func run(_ app: AppModel) {
        guard let folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fill(app)
        let steps: [(String, () -> Void)] = [
            ("clean-welcome", { app.tab = .clean; app.clean.phase = .idle; app.clean.preview = nil }),
            ("clean-found", { app.clean.preview = demoPreview; app.clean.phase = .found }),
            ("clean-done", { app.clean.result = RunSummary(bytes: 7_910_000_000, items: 2140); app.clean.phase = .done }),
            ("overview", { app.tab = .overview }),
            ("disk", { app.tab = .disk }),
            ("tools", { app.tab = .tools; app.toolScreen = nil }),
            ("uninstall", { app.toolScreen = .uninstall }),
            ("status", { app.toolScreen = nil; app.tab = .status }),
            ("history", { app.tab = .history })
        ]
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.setContentSize(NSSize(width: 1240, height: 800))
                window.center()
            }
            for (index, (name, setup)) in steps.enumerated() {
                setup()
                try? await Task.sleep(for: .seconds(index == 0 ? 3.2 : 1.6))
                capture(to: folder.appendingPathComponent("\(name).png"))
            }
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private static func capture(to url: URL) {
        guard let view = NSApp.windows.first(where: { $0.isVisible })?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    // MARK: - made-up data

    @MainActor
    private static func fill(_ app: AppModel) {
        app.language = .en
        let home = NSHomeDirectory()
        DiskSpace.override = (182_400_000_000, 494_380_000_000)
        app.updates.installed = "1.71.0"
        app.updates.state = .upToDate

        demoPreview = CleanListParser.parse("""
        === User essentials ===
        \(home)/Library/Caches  # 3.21GB, 64 items
        \(home)/Library/Logs  # 90.0MB
        === Browsers ===
        \(home)/Library/Caches/Google/Chrome/Default  # 1.18GB
        \(home)/Library/Caches/Firefox  # 840.0MB
        === Developer tools ===
        \(home)/Library/Developer/Xcode/DerivedData  # 1.55GB
        \(home)/.npm/_cacache  # 870.0MB
        === Application Support ===
        \(home)/Library/Application Support/Code/Cache  # 710.0MB
        === Apps & utilities ===
        \(home)/Library/Application Support/Slack/Cache  # 460.0MB
        === App caches ===
        \(home)/Library/Containers/com.apple.Safari/Data/Library/Caches  # 310.0MB
        """)
        app.clean.live = ["User essentials", "App caches", "Browsers", "Cloud & Office", "Developer tools", "Apps & utilities",
                          "Virtualization", "Application Support", "Time Machine"].map { CleanModel.LiveSection(title: $0) }

        let status = """
        {"uptime":"3d 4h","hardware":{"model":"MacBook Pro","cpu_model":"Apple M3 Pro","total_ram":"18.0 GB","os_version":"macOS 15.2"},
         "health_score":92,"health_score_msg":"Good","trash_size":1240000000,
         "cpu":{"usage":18.4,"per_core":[42,35,28,22,18,12,9,14,7,5,4,6],"load1":2.31,"core_count":12,"p_core_count":6,"e_core_count":6},
         "memory":{"used":11800000000,"total":18000000000,"used_percent":65.5,"pressure":"normal"},
         "disks":[{"mount":"/","used":312000000000,"total":494380000000,"used_percent":63.1,"smart_status":"verified"}],
         "batteries":[{"percent":86,"status":"charging","time_left":"0:42","health":"Good","cycle_count":212}],
         "top_processes":[{"pid":1,"name":"WindowServer","cpu":21.3,"memory_bytes":240000000},
                          {"pid":2,"name":"Xcode","cpu":14.8,"memory_bytes":1900000000},
                          {"pid":3,"name":"Safari","cpu":9.2,"memory_bytes":820000000},
                          {"pid":4,"name":"Slack","cpu":4.1,"memory_bytes":610000000},
                          {"pid":5,"name":"Music","cpu":1.7,"memory_bytes":180000000}]}
        """
        app.status.snapshot = try? MoleJSON.decode(StatusSnapshot.self, from: status)

        app.purge.preview = PurgeParser.parse("""
        ✓ [DRY RUN] ~/Projects/web-app/node_modules, 624.0MB
        ✓ [DRY RUN] ~/Projects/ios-app/.build, 412.0MB
        ✓ [DRY RUN] ~/Projects/ml-notebook/.venv, 286.0MB
        """)
        app.purge.phase = .ready
        app.purge.deselected = ["~/Projects/ml-notebook/.venv"]

        let history = """
        {"sessions":[
          {"command":"clean","started_at":"\(stamp(-0.2))","items":2140,"size":"7.91GB","actions":{"removed":2140}},
          {"command":"clean-dry-run","started_at":"\(stamp(-0.25))","items":2140,"size":"7.91GB","actions":{"removed":0}},
          {"command":"purge","started_at":"\(stamp(-3))","items":3,"size":"1.32GB","actions":{"removed":3}},
          {"command":"optimize","started_at":"\(stamp(-26))","items":18,"size":"0B","actions":{"removed":0}},
          {"command":"clean","started_at":"\(stamp(-170))","items":1630,"size":"5.40GB","actions":{"removed":1630}}]}
        """
        app.history.sessions = (try? MoleJSON.decode(HistoryResult.self, from: history))?.sessions ?? []

        func entry(_ name: String, _ path: String, _ gb: Double, dir: Bool = true) -> AnalyzeResult.Entry {
            try! MoleJSON.decode(AnalyzeResult.Entry.self,
                                 from: #"{"name":"\#(name)","path":"\#(path)","size":\#(Int64(gb * 1e9)),"is_dir":\#(dir)}"#)
        }
        func big(_ name: String, _ path: String, _ gb: Double) -> AnalyzeResult.LargeFile {
            try! MoleJSON.decode(AnalyzeResult.LargeFile.self, from: #"{"name":"\#(name)","path":"\#(path)","size":\#(Int64(gb * 1e9))}"#)
        }
        app.disk.stack = [DiskModel.Level(path: nil, title: "Macintosh HD", entries: [
            entry("User Library", home + "/Library", 61.2),
            entry("Applications", "/Applications", 38.4),
            entry("Home", home, 24.9),
            entry("Docker", home + "/Library/Containers/com.docker.docker", 18.2),
            entry("System Library", "/Library", 3.1),
            entry("Homebrew Cache", home + "/Library/Caches/Homebrew", 1.8),
            entry("Gradle Cache", home + "/.gradle/caches", 0.9),
            entry("System Logs", "/private/var/log", 0.12)
        ], largeFiles: [
            big("ubuntu-24.04.iso", home + "/Downloads/ubuntu-24.04.iso", 6.1),
            big("Xcode_16.xip", home + "/Downloads/Xcode_16.xip", 3.4),
            big("screen-recording.mov", home + "/Movies/screen-recording.mov", 1.2)
        ])]

        app.tools.apps = ["Docker", "Figma", "Notion", "Slack", "Spotify", "Zoom"].map {
            try! MoleJSON.decode(InstalledApp.self, from: #"{"name":"\#($0)","bundle_id":"com.example.\#($0.lowercased())","source":"App"}"#)
        }
        app.tools.selectedApp = app.tools.apps.first
        app.tools.uninstallPreview = UninstallPreview.parse("""
        Files to be removed:
          ✓ /Applications/Docker.app , 2.10GB
          ✓ \(home)/Library/Containers/com.docker.docker , 18.20GB
        Personal data kept:
          ⊙ ~/Library/Preferences/com.docker.docker.plist
        """)
        app.tools.slim = SlimPreview.parse("  Slack     182.0MB\n  Zoom      96.0MB\n2 apps, 278.0MB of Intel code")
        app.tools.optimize = OptimizePreview.parse("")
        app.tools.installer = InstallerPreview.parse("✓ No installer files to clean")
    }

    private static func stamp(_ hours: Double) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: Date().addingTimeInterval(hours * 3600))
    }
}
