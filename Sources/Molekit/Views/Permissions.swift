import SwiftUI
import AppKit

/// Full Disk Access. macOS (TCC) hides folders such as ~/Library/Safari, Mail and other apps'
/// containers from apps without it; Mole runs inside Molekit, so it silently skips them.
/// There is no public API to ask for the status, so we try to read a folder macOS protects.
@MainActor
final class PermissionModel: ObservableObject {
    @Published var hasFullDiskAccess = true
    private var observer: NSObjectProtocol?

    init() {
        check()
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func check() {
        let home = NSHomeDirectory()
        let probes = ["/Library/Safari", "/Library/Mail"].map { home + $0 }
            .filter { FileManager.default.fileExists(atPath: $0) }
        // No protected folder to test: assume access rather than nag.
        guard !probes.isEmpty else { hasFullDiskAccess = true; return }
        hasFullDiskAccess = probes.contains { (try? FileManager.default.contentsOfDirectory(atPath: $0)) != nil }
    }

    /// System Settings → Privacy & Security → Full Disk Access
    /// (pane and anchor IDs checked in /System/Library/ExtensionKit/Extensions/SecurityPrivacyExtension.appex).
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct FullDiskAccessBanner: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var model: PermissionModel
    private let amber = Color(hex: 0xF2C46B)

    var body: some View {
        if !model.hasFullDiskAccess {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.ui(18, .semibold)).foregroundStyle(amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t("fda.title")).font(.ui(13, .bold)).foregroundStyle(amber)
                    Text(app.t("fda.body")).font(.ui(12)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(app.t("fda.open")) { PermissionModel.openSettings() }.buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .glassCard(radius: 14, highlighted: amber)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
