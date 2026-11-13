import SwiftUI
import AppKit
import SwiftTerm
import MoleKitCore

// MARK: - In-app terminal

/// Runs one `mo` command in a real terminal inside the window. Used for the steps where
/// Mole insists on its own interactive confirmation (uninstall, slim, installer, optimize).
struct MoleTerminal: NSViewRepresentable {
    let executable: String
    let arguments: [String]
    let onExit: (Int32?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onExit: onExit) }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        view.font = NSFont(name: "JetBrains Mono", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.nativeBackgroundColor = NSColor(srgbRed: 0.04, green: 0.07, blue: 0.12, alpha: 1)
        view.nativeForegroundColor = NSColor(srgbRed: 0.93, green: 0.95, blue: 0.98, alpha: 1)
        view.caretColor = NSColor(srgbRed: 0.25, green: 0.88, blue: 1, alpha: 1)
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        view.startProcess(executable: executable, args: arguments,
                          environment: env.map { "\($0.key)=\($0.value)" }, execName: "mo")
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let onExit: (Int32?) -> Void
        init(onExit: @escaping (Int32?) -> Void) { self.onExit = onExit }
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { self.onExit(exitCode) }
        }
    }
}

/// Bottom panel with the terminal, a title and a close button.
struct TerminalPanel: View {
    @EnvironmentObject var app: AppModel
    let title: String
    let arguments: [String]
    let onClose: (Bool) -> Void     // true when mo finished successfully
    @State private var finished: Int32?? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(finished == nil ? Theme.green : Theme.tertiary).frame(width: 8, height: 8)
                    .shadow(color: finished == nil ? Theme.green : .clear, radius: 4)
                Text(title).font(.mono(13, .semibold))
                Spacer()
                Text(statusText).font(.ui(12)).foregroundStyle(Theme.secondary)
                Button(app.t("term.close")) { onClose(finished == .some(0)) }.buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 16).frame(height: 52)
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            if let path = app.cli?.executable.path {
                MoleTerminal(executable: path, arguments: arguments) { code in finished = .some(code) }
                    .padding(10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x0A121F)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: -4)
    }

    private var statusText: String {
        switch finished {
        case nil: return app.t("term.hint")
        case .some(0): return app.t("term.done")
        default: return app.t("term.ended")
        }
    }
}

// MARK: - Shared layout for a tool screen

struct ToolScreenLayout<Content: View, Footer: View>: View {
    @EnvironmentObject var app: AppModel
    let title: String
    let subtitle: String
    let command: String
    @Binding var terminal: [String]?
    var onTerminalDone: (Bool) -> Void = { _ in }
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                Button("‹ " + app.t("nav.tools")) { app.toolScreen = nil }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent).font(.ui(13, .semibold))
                PageHeader(title: title, subtitle: subtitle) {
                    Text(command).font(.mono(12)).foregroundStyle(Theme.text.opacity(0.78))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.28)))
                }
                content.frame(maxHeight: .infinity)
                footer
            }
            .padding(.top, 20).padding(.horizontal, 24).padding(.bottom, 22)

            if let args = terminal {
                Color.black.opacity(0.35).ignoresSafeArea().onTapGesture {}
                TerminalPanel(title: "mo " + args.joined(separator: " "), arguments: args) { ok in
                    terminal = nil
                    onTerminalDone(ok)
                }
                .frame(height: 380)
                .padding(18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: terminal != nil)
    }
}

/// Footer bar: summary on the left, the main button on the right.
struct ActionBar: View {
    let summary: Text
    let button: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        HStack {
            summary.font(.ui(14))
            Spacer()
            Button(button, action: action)
                .buttonStyle(PrimaryButtonStyle(large: false))
                .disabled(!enabled).opacity(enabled ? 1 : 0.5)
        }
        .padding(.leading, 22).padding(.trailing, 12).padding(.vertical, 12)
        .glassCard(radius: 20, highlighted: .white)
    }
}

/// Placeholder shown before the first preview: the user starts every scan.
struct ScanPrompt: View {
    @EnvironmentObject var app: AppModel
    let symbol: String
    let text: String
    let busy: Bool
    let action: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            BigTile(symbol: symbol, size: 96)
            Text(text).font(.ui(14)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
            if busy {
                ProgressView().controlSize(.large)
            } else {
                Button(app.t("clean.scan"), action: action).buttonStyle(PrimaryButtonStyle(large: false))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Uninstall

struct UninstallView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var tools: ToolsModel
    @State private var query = ""
    @State private var terminal: [String]?

    private var filtered: [InstalledApp] {
        query.isEmpty ? tools.apps : tools.apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ToolScreenLayout(title: app.t("tools.uninstall.title"), subtitle: app.t("uninstall.subtitle"), command: "mo uninstall",
                   terminal: $terminal, onTerminalDone: { _ in tools.apps = []; tools.selectedApp = nil; tools.load() }) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.tertiary)
                        TextField(app.t("uninstall.search"), text: $query).textFieldStyle(.plain).font(.ui(14))
                    }
                    .padding(.horizontal, 14).frame(height: 40).glassCard(radius: 12)
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            if tools.appsLoading { ProgressView().padding(30) }
                            ForEach(filtered) { item in appRow(item) }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 360)
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } footer: {
            ActionBar(summary: Text(tools.selectedApp.map { app.t("uninstall.selected", $0.name) } ?? app.t("uninstall.pick")),
                      button: app.t("uninstall.run"), enabled: tools.selectedApp != nil && !tools.previewLoading) {
                if let a = tools.selectedApp { terminal = ["uninstall", a.uninstallName ?? a.name] }
            }
        }
        .onAppear { tools.load() }
    }

    private func appRow(_ item: InstalledApp) -> some View {
        let on = tools.selectedApp == item
        return Button { tools.select(item) } label: {
            HStack(spacing: 12) {
                AppIcon(path: item.path)
                Text(item.name).font(.ui(14, on ? .bold : .medium)).lineLimit(1)
                Spacer()
                if item.source == "Homebrew" || item.source?.lowercased().contains("brew") == true {
                    Text("brew").font(.ui(11, .semibold)).foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 12).frame(height: 44)
            .glassCard(radius: 12, highlighted: on ? Theme.accent : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var detail: some View {
        if let selected = tools.selectedApp {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    AppIcon(path: selected.path, size: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selected.name).font(.ui(22, .heavy))
                        Text(selected.bundleId ?? "").font(.mono(12)).foregroundStyle(Theme.tertiary)
                    }
                    Spacer()
                    if let p = tools.uninstallPreview, p.totalBytes > 0 {
                        Text(app.size(p.totalBytes)).font(.ui(26, .heavy)).foregroundStyle(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.35), radius: 8)
                    }
                }
                if tools.previewLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(30)
                } else if let p = tools.uninstallPreview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(app.t("uninstall.willRemove")).font(.ui(13, .semibold)).foregroundStyle(Theme.text.opacity(0.8))
                            ForEach(p.remove) { f in
                                HStack {
                                    Image(systemName: "trash").foregroundStyle(Theme.red.opacity(0.8))
                                    Text(PathDisplay.tilde(f.path)).font(.mono(12)).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    if let b = f.bytes { Text(app.size(b)).font(.ui(12, .semibold)) }
                                }
                                .contextMenu { RevealButton(path: f.path) }
                            }
                            if !p.keep.isEmpty {
                                Text(app.t("uninstall.keeps")).font(.ui(13, .semibold)).foregroundStyle(Theme.text.opacity(0.8)).padding(.top, 6)
                                ForEach(p.keep, id: \.self) { path in
                                    HStack {
                                        Image(systemName: "lock.shield").foregroundStyle(Theme.green)
                                        Text(PathDisplay.tilde(path)).font(.mono(12)).foregroundStyle(Theme.secondary)
                                            .lineLimit(1).truncationMode(.middle)
                                    }
                                }
                                Text(app.t("uninstall.keepsHint")).font(.ui(12)).foregroundStyle(Theme.tertiary)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                Spacer(minLength: 0)
            }
            .padding(20).glassCard(radius: 20)
        } else {
            VStack(spacing: 14) {
                BigTile(symbol: "trash.fill", size: 96)
                Text(app.t("uninstall.pickHint")).font(.ui(14)).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).glassCard(radius: 20)
        }
    }
}

struct AppIcon: View {
    let path: String?
    var size: CGFloat = 28
    var body: some View {
        if let path, FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: size, height: size)
        } else {
            GlyphTile(symbol: "app.dashed", size: size)
        }
    }
}

// MARK: - Optimize

struct OptimizeView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var tools: ToolsModel
    @State private var terminal: [String]?

    var body: some View {
        ToolScreenLayout(title: app.t("tools.optimize.title"), subtitle: app.t("optimize.subtitle"), command: "mo optimize",
                   terminal: $terminal, onTerminalDone: { _ in tools.loadOptimize(force: true) }) {
            if let p = tools.optimize {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(p.steps) { step in
                            HStack(alignment: .top, spacing: 12) {
                                GlyphTile(symbol: step.needsAttention ? "exclamationmark" : "checkmark", size: 36,
                                          tint: step.needsAttention ? Color(hex: 0xF2C46B) : Theme.green)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(step.section).font(.ui(14, .semibold))
                                    ForEach(step.lines, id: \.self) { Text($0).font(.ui(12)).foregroundStyle(Theme.secondary) }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).glassCard(radius: 14)
                        }
                    }
                }
                .scrollIndicators(.never)
            } else {
                ScanPrompt(symbol: "bolt.fill", text: app.t("optimize.prompt"), busy: tools.loading.contains("optimize")) {
                    tools.loadOptimize(force: true)
                }
            }
        } footer: {
            ActionBar(summary: Text(tools.optimize.map { app.t("optimize.summary", $0.steps.count) } ?? ""),
                      button: app.t("optimize.run"), enabled: tools.optimize != nil) {
                terminal = ["optimize"]
            }
        }
    }
}

// MARK: - Slim

struct SlimView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var tools: ToolsModel
    @State private var terminal: [String]?

    var body: some View {
        ToolScreenLayout(title: app.t("tools.slim.title"), subtitle: app.t("slim.subtitle"), command: "mo slim",
                   terminal: $terminal, onTerminalDone: { _ in tools.loadSlim(force: true) }) {
            if let p = tools.slim {
                let maxBytes = Double(p.apps.first?.bytes ?? 1)
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(p.apps) { a in
                            HStack(spacing: 14) {
                                AppIcon(path: "/Applications/\(a.name).app", size: 36)
                                Text(a.name).font(.ui(14, .semibold)).frame(width: 240, alignment: .leading).lineLimit(1)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.black.opacity(0.35))
                                        Capsule().fill(Theme.barGradient).frame(width: max(4, geo.size.width * Double(a.bytes) / maxBytes))
                                    }
                                }
                                .frame(height: 8)
                                Text(app.size(a.bytes)).font(.ui(14, .bold)).monospacedDigit().frame(width: 84, alignment: .trailing)
                            }
                            .padding(.horizontal, 14).frame(height: 54).glassCard()
                        }
                    }
                }
                .scrollIndicators(.never)
            } else {
                ScanPrompt(symbol: "cpu.fill", text: app.t("slim.prompt"), busy: tools.loading.contains("slim")) {
                    tools.loadSlim(force: true)
                }
            }
        } footer: {
            ActionBar(summary: Text(tools.slim.map { app.t("slim.summary", $0.apps.count, app.size($0.total)) } ?? ""),
                      button: app.t("slim.run"), enabled: (tools.slim?.apps.isEmpty == false)) {
                terminal = ["slim"]
            }
        }
    }
}

// MARK: - Installers

struct InstallerView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var tools: ToolsModel
    @State private var terminal: [String]?

    var body: some View {
        ToolScreenLayout(title: app.t("tools.installer.title"), subtitle: app.t("installer.subtitle"), command: "mo installer",
                   terminal: $terminal, onTerminalDone: { _ in tools.loadInstaller(force: true) }) {
            if let p = tools.installer {
                if p.files.isEmpty {
                    VStack(spacing: 14) {
                        BigTile(symbol: "checkmark", size: 96)
                        Text(app.t("installer.none")).font(.ui(16, .semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(p.files) { f in
                                HStack(spacing: 14) {
                                    GlyphTile(symbol: "shippingbox")
                                    Text(PathDisplay.tilde(f.path)).font(.ui(14, .semibold)).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    if let b = f.bytes { Text(app.size(b)).font(.ui(14, .bold)).monospacedDigit() }
                                }
                                .padding(.horizontal, 14).frame(height: 58).glassCard()
                                .contextMenu { RevealButton(path: (f.path as NSString).expandingTildeInPath) }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            } else {
                ScanPrompt(symbol: "arrow.down.to.line", text: app.t("installer.prompt"), busy: tools.loading.contains("installer")) {
                    tools.loadInstaller(force: true)
                }
            }
        } footer: {
            ActionBar(summary: Text(tools.installer.map { $0.files.isEmpty ? app.t("tools.nothing") : app.t("tools.files", $0.files.count) } ?? ""),
                      button: app.t("installer.run"), enabled: tools.installer?.files.isEmpty == false) {
                terminal = ["installer"]
            }
        }
    }
}
