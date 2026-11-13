import SwiftUI
import MoleKitCore

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var status: StatusModel
    @ObservedObject var clean: CleanModel
    @ObservedObject var purge: PurgeModel
    @ObservedObject var history: HistoryModel

    var body: some View {
        // Scrolls only when it does not fit (e.g. with the Full Disk Access banner on a small window).
        ViewThatFits(in: .vertical) {
            page
            ScrollView { page }.scrollIndicators(.automatic)
        }
        .onAppear { status.refreshOnce(); history.load() }
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: app.t("nav.overview"), subtitle: "Small mole. Big cleanup.")
            FullDiskAccessBanner(model: app.permissions)
            HStack(alignment: .top, spacing: 14) {
                healthCard.frame(width: 300)
                VStack(spacing: 16) {
                    macCard
                    TipsTicker()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Text(app.t("overview.actions")).font(.ui(15, .semibold)).foregroundStyle(Theme.text.opacity(0.8))
            HStack(spacing: 14) {
                actionCard(symbol: "sparkles", title: app.t("nav.clean"), hint: app.t("overview.clean.hint"),
                           value: clean.preview.map { app.size($0.total) } ?? app.t("overview.scan")) { app.tab = .clean }
                actionCard(symbol: "folder.badge.gearshape", title: app.t("tools.purge.title"), hint: "build, node_modules, .venv",
                           value: purge.preview.map { app.size($0.total) } ?? app.t("overview.scan")) { app.tab = .tools; app.toolScreen = .purge }
                actionCard(symbol: "trash.fill", title: app.t("overview.trash"), hint: app.t("overview.trash.hint"),
                           value: status.snapshot?.trashSize.map(app.size) ?? "—") { NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")) }
            }
            HStack {
                if let last = history.lastRealClean {
                    Text(app.t("overview.lastClean", HistoryModel.date(last.startedAt).map { $0.formatted(Date.RelativeFormatStyle(presentation: .named).locale(Locale(identifier: app.language == .uk ? "uk_UA" : "en_US"))) } ?? (last.startedAt ?? ""), app.size(last.sizeBytes)))
                } else {
                    Text(app.t("overview.noClean"))
                }
                Spacer()
                Button(app.t("nav.history") + " ›") { app.tab = .history }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent).font(.ui(13, .semibold))
            }
            .font(.ui(13)).foregroundStyle(Theme.text.opacity(0.85))
            .padding(.horizontal, 18).padding(.vertical, 14).glassCard()
        }
        .padding(.top, 26).padding(.horizontal, 24).padding(.bottom, 22)
    }

    private var healthCard: some View {
        VStack(spacing: 14) {
            Text(app.t("overview.health")).font(.ui(15, .semibold)).foregroundStyle(Theme.text.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                ProgressRing(progress: Double(status.snapshot?.healthScore ?? 0) / 100, size: 150, lineWidth: 8)
                VStack(spacing: 2) {
                    Text("\(status.snapshot?.healthScore ?? 0)").font(.ui(42, .heavy)).monospacedDigit()
                    Text(app.t("overview.of100")).font(.ui(13)).foregroundStyle(Theme.secondary)
                }
            }
            Text(healthWord).font(.ui(16, .bold)).foregroundStyle(Theme.accent)
        }
        .padding(22).frame(maxHeight: .infinity).glassCard(radius: 18)
    }

    private var healthWord: String {
        guard let score = status.snapshot?.healthScore else { return "—" }
        return app.t(score >= 90 ? "health.excellent" : score >= 70 ? "health.good" : score >= 50 ? "health.fair" : "health.poor")
    }

    private var macCard: some View {
        let s = status.snapshot
        // Each tile opens the matching place in macOS (pane IDs checked in /System/Library/ExtensionKit).
        let specs: [(String, String, SystemLink)] = [
            (app.t("mac.model"), s?.hardware?.model ?? "—", .about),
            (app.t("mac.cpu"), [s?.hardware?.cpuModel, s?.cpu?.coreCount.map { app.t("mac.cores", $0) }].compactMap { $0 }.joined(separator: " · "), .about),
            (app.t("mac.memory"), s?.hardware?.totalRam ?? "—", .activityMonitor),
            (app.t("mac.system"), s?.hardware?.osVersion ?? "—", .softwareUpdate),
            (app.t("mac.uptime"), s?.uptime ?? "—", .activityMonitor),
            (app.t("mac.battery"), s?.batteries?.first.map { "\(Int($0.percent ?? 0))% · \($0.health ?? "")" } ?? "—", .battery)
        ]
        return VStack(alignment: .leading, spacing: 16) {
            Text(app.t("overview.thisMac")).font(.ui(15, .semibold)).foregroundStyle(Theme.text.opacity(0.8))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(specs, id: \.0) { k, v, link in
                    SpecTile(title: k, value: v.isEmpty ? "—" : v, link: link)
                }
            }
            Button { SystemLink.storage.open() } label: { DiskBar() }
                .buttonStyle(.plain)
                .hoverLift()
                .help(app.t("link.storage"))
        }
        .padding(22).glassCard(radius: 18)
    }

    private func actionCard(symbol: String, title: String, hint: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                BigTile(symbol: symbol, size: 64)
                VStack(spacing: 3) {
                    Text(title).font(.ui(17, .bold))
                    Text(hint).font(.ui(13)).foregroundStyle(Theme.secondary).lineLimit(1)
                    Text(value).font(.ui(24, .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.accent).shadow(color: Theme.accent.opacity(0.35), radius: 8).padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            .glassCard(radius: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverLift(radius: 22)
    }
}

// MARK: - Tools

struct ToolsView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var tools: ToolsModel
    @ObservedObject var purge: PurgeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: app.t("nav.tools"), subtitle: app.t("tools.subtitle"))
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    card(symbol: "folder.badge.gearshape", title: app.t("tools.purge.title"), command: "mo purge", desc: app.t("tools.purge.desc"),
                         status: purge.preview.map { app.size($0.total) } ?? app.t("tools.notScanned"), highlight: purge.preview != nil,
                         action: app.t("tools.open"), primary: true) { app.toolScreen = .purge }
                    card(symbol: "trash.fill", title: app.t("tools.uninstall.title"), command: "mo uninstall", desc: app.t("tools.uninstall.desc"),
                         status: tools.appCount.map { app.t("tools.apps", $0) } ?? "…", action: app.t("tools.open")) { app.toolScreen = .uninstall }
                    card(symbol: "bolt.fill", title: app.t("tools.optimize.title"), command: "mo optimize", desc: app.t("tools.optimize.desc"),
                         status: tools.optimize.map { app.t("tools.steps", $0.steps.count) } ?? "", action: app.t("tools.open")) { app.toolScreen = .optimize }
                }
                GridRow {
                    card(symbol: "arrow.down.to.line", title: app.t("tools.installer.title"), command: "mo installer", desc: app.t("tools.installer.desc"),
                         status: tools.installer.map { $0.files.isEmpty ? app.t("tools.nothing") : app.t("tools.files", $0.files.count) } ?? "", action: app.t("tools.open")) { app.toolScreen = .installer }
                    card(symbol: "cpu.fill", title: app.t("tools.slim.title"), command: "mo slim", desc: app.t("tools.slim.desc"),
                         status: tools.slim.map { app.size($0.total) } ?? "", highlight: tools.slim != nil, action: app.t("tools.open")) { app.toolScreen = .slim }
                    Color.clear
                }
            }
        }
        .padding(.top, 26).padding(.horizontal, 24).padding(.bottom, 22)
        .onAppear { tools.load() }
    }

    private func card(symbol: String, title: String, command: String, desc: String, status: String, highlight: Bool = false,
                      action: String, primary: Bool = false, perform: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            BigTile(symbol: symbol, size: 96)
            Text(title).font(.ui(17, .bold)).padding(.top, 4)
            Text(command).font(.mono(12)).foregroundStyle(Theme.text.opacity(0.78))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.28)))
            Text(desc).font(.ui(13)).foregroundStyle(Theme.text.opacity(0.66)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Text(status).font(.ui(14, .bold)).lineLimit(1)
                    .foregroundStyle(highlight ? Theme.accent : Theme.text.opacity(0.78))
                Spacer(minLength: 0)
                Button(action, action: perform).buttonStyle(GhostButtonStyle())
            }
        }
        .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(radius: 22)
        .contentShape(Rectangle())
        .onTapGesture(perform: perform)
        .hoverLift(radius: 22)
    }
}

// MARK: - Purge (project build output)

struct PurgeView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var model: PurgeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { app.toolScreen = nil } label: { Label(app.t("nav.tools"), systemImage: "chevron.left") }
                .buttonStyle(GhostButtonStyle())
            PageHeader(title: app.t("tools.purge.title"), subtitle: app.t("purge.subtitle")) {
                if model.phase != .idle {
                    Button(app.t("purge.rescan")) { model.scan() }.buttonStyle(GhostButtonStyle())
                }
            }
            ScrollView {
                LazyVStack(spacing: 6) {
                    switch model.phase {
                    case .idle:
                        ScanPrompt(symbol: "folder.badge.gearshape", text: app.t("purge.prompt"), busy: false) { model.scan() }
                            .frame(height: 420)
                    case .scanning:
                        ProgressView().controlSize(.large).padding(40)
                    case .failed(let message):
                        Text(message).foregroundStyle(Theme.red).padding()
                    default:
                        if model.items.isEmpty {
                            Text(app.t("purge.empty")).foregroundStyle(Theme.secondary).padding(30)
                        }
                        ForEach(model.items) { item in row(item) }
                    }
                }
            }
            .scrollIndicators(.never)
            HStack {
                Group {
                    if model.phase == .done {
                        Text(app.t("purge.done", app.size(model.freed)))
                    } else {
                        Text(app.t("purge.selected")) + Text(" " + app.size(model.selectedBytes)).foregroundColor(Theme.accent).bold()
                    }
                }
                .font(.ui(14))
                Spacer()
                Button(app.t("purge.run")) { model.run() }
                    .buttonStyle(PrimaryButtonStyle(large: false))
                    .disabled(model.phase != .ready || model.selectedBytes == 0)
                    .opacity(model.phase == .ready && model.selectedBytes > 0 ? 1 : 0.5)
            }
            .padding(.leading, 22).padding(.trailing, 12).padding(.vertical, 12)
            .glassCard(radius: 20, highlighted: .white)
        }
        .padding(.top, 20).padding(.horizontal, 24).padding(.bottom, 22)
    }

    private func row(_ item: PurgePreview.Item) -> some View {
        HStack(spacing: 14) {
            GreenCheckbox(isOn: Binding(get: { !model.deselected.contains(item.path) }, set: { _ in model.toggle(item.path) }), label: item.path)
            GlyphTile(symbol: symbol(item.kind))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.path).font(.ui(14, .semibold)).lineLimit(1).truncationMode(.middle)
                Text(app.t(item.needsManualRestore ? "purge.manual" : "purge.rebuilds"))
                    .font(.ui(12)).foregroundStyle(item.needsManualRestore ? Color(hex: 0xF2C46B) : Theme.text.opacity(0.6))
            }
            Spacer()
            Text(item.kind).font(.ui(12, .semibold)).foregroundStyle(Theme.text.opacity(0.82))
                .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(.black.opacity(0.25)))
            Text(app.size(item.bytes)).font(.ui(14, .bold)).monospacedDigit().frame(width: 86, alignment: .trailing)
        }
        .padding(.horizontal, 16).frame(height: 60).glassCard()
    }

    private func symbol(_ kind: String) -> String {
        switch kind {
        case "node_modules": return "shippingbox"
        case "Python venv", "Python cache": return "chevron.left.forwardslash.chevron.right"
        case "Swift build": return "swift"
        case "Gradle": return "cube"
        default: return "hammer"
        }
    }
}

// MARK: - Disk

/// TreeSize-style list: biggest first, click a folder to go inside.
/// Molekit never deletes from here; "Show in Finder" hands control to you.
struct DiskView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var model: DiskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: app.t("disk.title"), subtitle: app.t("disk.subtitle"))
            HStack(spacing: 10) {
                Button("‹ " + app.t("disk.back")) { model.back() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.stack.count <= 1)
                    .opacity(model.stack.count <= 1 ? 0.4 : 1)
                breadcrumb
            }
            HStack(alignment: .top, spacing: 14) {
                list.frame(maxWidth: .infinity)
                side.frame(width: 300)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 26).padding(.horizontal, 24).padding(.bottom, 22)
        .onAppear { if model.stack.isEmpty { model.loadRoot() } }
    }

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive.fill").foregroundStyle(Theme.accent.opacity(0.8))
            ForEach(Array(model.stack.enumerated()), id: \.offset) { i, level in
                if i > 0 { Text("›").foregroundStyle(Theme.tertiary) }
                Button(level.title) { model.jump(to: i) }
                    .buttonStyle(.plain)
                    .fontWeight(i == model.stack.count - 1 ? .bold : .regular)
                    .foregroundStyle(i == model.stack.count - 1 ? Theme.text : Theme.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if model.loading { ProgressView().controlSize(.small) }
            if let level = model.current {
                Text(app.t("disk.inFolder", app.size(level.total), level.entries.count)).foregroundStyle(Theme.secondary)
            }
        }
        .font(.ui(13))
        .padding(.horizontal, 16).frame(height: 40)
        .glassCard(radius: 12)
    }

    @ViewBuilder private var list: some View {
        if let error = model.error {
            Text(error).foregroundStyle(Theme.red).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let level = model.current {
            let maxSize = Double(level.entries.first?.size ?? 1)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(level.entries) { entry in
                        DiskRow(entry: entry, fraction: Double(entry.size) / maxSize,
                                share: Double(entry.size) / Double(max(level.total, 1))) {
                            model.open(path: entry.path, title: entry.name)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.never)
            .opacity(model.loading ? 0.5 : 1)
        } else {
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text(app.t("disk.loading")).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var side: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Macintosh HD").font(.ui(15, .semibold)).foregroundStyle(Theme.text.opacity(0.8))
                if let space = DiskSpace.root() {
                    (Text(app.size(space.free)).foregroundColor(Theme.accent) + Text("  " + app.t("disk.free")).font(.ui(15, .semibold)).foregroundColor(Theme.secondary))
                        .font(.ui(30, .heavy))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 8)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.black.opacity(0.35))
                            Capsule().fill(Theme.barGradient)
                                .frame(width: geo.size.width * CGFloat(Double(space.total - space.free) / Double(max(space.total, 1))))
                                .shadow(color: Theme.accent.opacity(0.55), radius: 5)
                        }
                    }
                    .frame(height: 8)
                    Text(app.t("disk.usedOf", app.size(space.total - space.free), app.size(space.total)))
                        .font(.ui(12)).foregroundStyle(Theme.secondary)
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading).glassCard(radius: 20)

            VStack(alignment: .leading, spacing: 10) {
                Text(app.t("disk.bigFiles")).font(.ui(15, .semibold)).foregroundStyle(Theme.text.opacity(0.8))
                let files = model.current?.largeFiles ?? []
                if files.isEmpty {
                    Text("—").foregroundStyle(Theme.tertiary)
                }
                ForEach(files) { file in
                    HStack(spacing: 10) {
                        Image(systemName: "doc").foregroundStyle(Theme.accent.opacity(0.8))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.name).font(.ui(13, .semibold)).lineLimit(1)
                            Text(PathDisplay.tilde((file.path as NSString).deletingLastPathComponent))
                                .font(.ui(11)).foregroundStyle(Theme.tertiary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer(minLength: 4)
                        Text(app.size(file.size)).font(.ui(13, .bold)).monospacedDigit()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.2)))
                    .contextMenu { RevealButton(path: file.path) }
                }
                Spacer(minLength: 0)
                Text(app.t("disk.rightClick")).font(.ui(12)).foregroundStyle(Theme.tertiary)
            }
            .padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).glassCard(radius: 20)
        }
    }
}

struct DiskRow: View {
    @EnvironmentObject var app: AppModel
    let entry: AnalyzeResult.Entry
    let fraction: Double
    let share: Double
    let open: () -> Void
    @State private var hover = false

    private var isFolder: Bool { entry.isDir != false }

    var body: some View {
        Button { if isFolder { open() } } label: {
            HStack(spacing: 14) {
                GlyphTile(symbol: isFolder ? (entry.path.hasSuffix(".app") ? "app" : "folder") : "doc")
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).font(.ui(14, .semibold)).lineLimit(1)
                    Text(PathDisplay.tilde(entry.path)).font(.ui(12)).foregroundStyle(Theme.text.opacity(0.58))
                        .lineLimit(1).truncationMode(.middle)
                }
                .frame(width: 230, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.35))
                        Capsule().fill(Theme.barGradient).frame(width: max(4, geo.size.width * fraction))
                            .shadow(color: Theme.accent.opacity(0.5), radius: 5)
                    }
                }
                .frame(height: 8)
                Text(share < 0.01 ? "<1%" : "\(Int((share * 100).rounded()))%")
                    .font(.ui(13)).monospacedDigit().foregroundStyle(Theme.text.opacity(0.7)).frame(width: 46, alignment: .trailing)
                Text(app.size(entry.size)).font(.ui(15, .bold)).monospacedDigit().frame(width: 84, alignment: .trailing)
                Image(systemName: "chevron.right").font(.ui(12, .bold))
                    .foregroundStyle(Theme.tertiary).opacity(isFolder ? 1 : 0)
            }
            .padding(.horizontal, 14).frame(height: 60)
            .glassCard(highlighted: hover && isFolder ? Theme.accent : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .contextMenu {
            if isFolder { Button(app.t("disk.openHere"), action: open) }
            RevealButton(path: entry.path)
        }
        .help(entry.path)
    }
}

/// "Show in Finder": Molekit never deletes from the Disk screen.
struct RevealButton: View {
    @EnvironmentObject var app: AppModel
    let path: String
    var body: some View {
        Button(app.t("disk.reveal")) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }
}

// MARK: - Status

struct StatusView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var model: StatusModel

    var body: some View {
        let s = model.snapshot
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: app.t("nav.status"), subtitle: app.t("status.subtitle")) { LiveChip(text: "Live") }
            HStack(spacing: 14) {
                tile(app.t("status.cpu"), String(format: "%.0f%%", s?.cpu?.usage ?? 0), (s?.cpu?.usage ?? 0) / 100,
                     app.t("status.cpuSub", s?.cpu?.load1 ?? 0, s?.cpu?.coreCount ?? 0))
                tile(app.t("mac.memory"), app.size(s?.memory?.used ?? 0), (s?.memory?.usedPercent ?? 0) / 100,
                     app.t("status.memSub", app.size(s?.memory?.total ?? 0), s?.memory?.pressure ?? "—"))
                diskTile
                tile(app.t("mac.battery"), "\(Int(s?.batteries?.first?.percent ?? 0))%", (s?.batteries?.first?.percent ?? 0) / 100,
                     [s?.batteries?.first?.timeLeft, s?.batteries?.first?.cycleCount.map { app.t("status.cycles", $0) }, s?.batteries?.first?.health]
                        .compactMap { $0 }.joined(separator: " · "))
            }
            HStack(alignment: .top, spacing: 14) {
                cores
                processes
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 26).padding(.horizontal, 24).padding(.bottom, 22)
        .onAppear { model.startLive() }
        .onDisappear { model.stopLive() }
    }

    private var diskTile: some View {
        let space = DiskSpace.root()
        let used = Double((space?.total ?? 0) - (space?.free ?? 0)) / Double(max(space?.total ?? 1, 1))
        return tile(app.t("status.disk"), app.t("status.free", app.size(space?.free ?? 0)), used,
                    app.t("status.diskSub", app.size(space?.total ?? 0), model.snapshot?.rootDisk?.smartStatus ?? "—"))
    }

    private func tile(_ title: String, _ value: String, _ fraction: Double, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.ui(13, .semibold)).foregroundStyle(Theme.text.opacity(0.7))
            Text(value).font(.ui(30, .heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.35))
                    Capsule().fill(Theme.barGradient).frame(width: geo.size.width * min(max(fraction, 0), 1))
                        .shadow(color: Theme.accent.opacity(0.55), radius: 5)
                }
            }
            .frame(height: 6)
            Text(sub).font(.ui(12)).foregroundStyle(Theme.secondary).lineLimit(1)
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
        .animation(.easeOut(duration: 0.4), value: fraction)
    }

    private var cores: some View {
        let per = model.snapshot?.cpu?.perCore ?? []
        let p = model.snapshot?.cpu?.pCoreCount ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            Text(app.t("status.cores")).font(.ui(15, .semibold))
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(per.enumerated()), id: \.offset) { i, v in
                    VStack(spacing: 6) {
                        Text("\(Int(v))%").font(.ui(11)).monospacedDigit().foregroundStyle(Theme.text.opacity(0.7))
                        GeometryReader { geo in
                            VStack { Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [Color(hex: 0x74ECFF).opacity(i < p ? 1 : 0.7), Theme.accentDeep.opacity(i < p ? 1 : 0.6)], startPoint: .top, endPoint: .bottom))
                                    .frame(height: max(3, geo.size.height * v / 100))
                                    .shadow(color: i < p ? Theme.accent.opacity(0.45) : .clear, radius: 6)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
                        Text(i < p ? "P\(i + 1)" : "E\(i - p + 1)").font(.ui(11)).foregroundStyle(Theme.tertiary)
                    }
                    .animation(.easeOut(duration: 0.4), value: v)
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).glassCard(radius: 18)
    }

    private var processes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(app.t("status.processes")).font(.ui(15, .semibold)).padding(.bottom, 6)
            ForEach((model.snapshot?.topProcesses ?? []).prefix(6)) { proc in
                HStack(spacing: 12) {
                    Text(proc.name ?? "?").font(.ui(14, .medium)).lineLimit(1)
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.black.opacity(0.35))
                            Capsule().fill(Theme.barGradient).frame(width: geo.size.width * min((proc.cpu ?? 0) / 100, 1))
                        }
                    }
                    .frame(width: 120, height: 6)
                    Text(String(format: "%.1f%%", proc.cpu ?? 0)).font(.ui(13, .bold)).monospacedDigit().frame(width: 58, alignment: .trailing)
                    Text(app.size(proc.memoryBytes ?? 0)).font(.ui(12)).foregroundStyle(Theme.secondary).monospacedDigit().frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.04)))
            }
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).glassCard(radius: 18)
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var model: HistoryModel
    @AppStorage("history.showPreviews") private var showPreviews = false

    /// Empty previews (0 found) mostly come from Molekit's own uninstall previews; hidden unless asked.
    private var visible: [HistoryResult.Session] {
        showPreviews ? model.sessions : model.sessions.filter { !($0.isPreview && ($0.items ?? 0) == 0) }
    }

    var body: some View {
        let today = model.today
        let freed = today.filter { !$0.isPreview }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let failed = today.reduce(0) { $0 + ($1.failedTasks ?? 0) + ($1.actions?.failed ?? 0) }
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: app.t("nav.history"), subtitle: app.t("history.subtitle"))
            HStack(spacing: 14) {
                stat("sparkles", app.t("history.freedToday"), app.size(freed), Theme.accent)
                stat("clock", app.t("history.runsToday"), "\(today.count)", Theme.accent)
                stat(failed == 0 ? "checkmark.shield.fill" : "xmark.shield.fill", app.t("history.errors"), "\(failed)", failed == 0 ? Theme.green : Theme.red,
                     alert: failed > 0)
            }
            HStack {
                Text(app.t("history.recent")).font(.ui(15, .semibold)).foregroundStyle(Theme.text.opacity(0.8))
                Spacer()
                Toggle(app.t("history.showPreviews"), isOn: $showPreviews)
                    .toggleStyle(.switch).controlSize(.small).tint(Theme.accent)
                    .font(.ui(13)).foregroundStyle(Theme.secondary)
            }
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(visible) { row($0) }
                    if model.sessions.isEmpty && !model.loading {
                        Text(app.t("history.empty")).foregroundStyle(Theme.secondary).padding(30)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(.top, 26).padding(.horizontal, 24).padding(.bottom, 22)
        .onAppear { model.load() }
    }

    private func stat(_ symbol: String, _ title: String, _ value: String, _ color: Color, alert: Bool = false) -> some View {
        HStack(spacing: 16) {
            GlyphTile(symbol: symbol, size: 64, tint: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(13, .semibold)).foregroundStyle(Theme.text.opacity(0.68))
                Text(value).font(.ui(30, .heavy)).monospacedDigit().foregroundStyle(color)
                    .shadow(color: color.opacity(0.35), radius: 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.vertical, 16).glassCard(radius: 22, highlighted: alert ? Theme.red : nil)
    }

    private func row(_ s: HistoryResult.Session) -> some View {
        let errors = (s.failedTasks ?? 0) + (s.actions?.failed ?? 0)
        if errors > 0 { return AnyView(errorRow(s, errors: errors)) }
        return AnyView(normalRow(s))
    }

    private func errorRow(_ s: HistoryResult.Session, errors: Int) -> some View {
        let date = HistoryModel.date(s.startedAt)
        return HStack(spacing: 14) {
            Text(date.map(shortDate) ?? "—")
                .font(.ui(13, .semibold)).monospacedDigit().foregroundStyle(Theme.text.opacity(0.78))
                .frame(width: 110, alignment: .leading)
            GlyphTile(symbol: symbol(s.baseCommand), tint: Theme.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(name(s.baseCommand)).font(.ui(14, .semibold))
                Text(app.t("history.seeLog")).font(.ui(12)).foregroundStyle(Theme.text.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "xmark").font(.ui(10, .heavy))
                Text(app.t("history.failed", errors))
            }
            .font(.ui(12, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xFF7676), Color(hex: 0xD9363F)], startPoint: .top, endPoint: .bottom)))
            .shadow(color: Theme.red.opacity(0.4), radius: 6)
            Text(s.sizeBytes > 0 ? app.size(s.sizeBytes) : "—").font(.ui(15, .bold)).monospacedDigit()
                .foregroundStyle(Theme.red).frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, 18).frame(height: 62)
        .glassCard(highlighted: Theme.red)
        .contextMenu { RevealButton(path: NSHomeDirectory() + "/Library/Logs/mole/operations.log") }
    }

    private func normalRow(_ s: HistoryResult.Session) -> some View {
        let done = !s.isPreview
        let date = HistoryModel.date(s.startedAt)
        return HStack(spacing: 14) {
            Text(date.map(shortDate) ?? "—")
                .font(.ui(13, .semibold)).monospacedDigit().foregroundStyle(Theme.text.opacity(0.78))
                .frame(width: 110, alignment: .leading)
            GlyphTile(symbol: symbol(s.baseCommand))
            VStack(alignment: .leading, spacing: 2) {
                Text(name(s.baseCommand)).font(.ui(14, .semibold))
                Text(app.t(done ? "history.itemsRemoved" : "history.itemsFound", s.items ?? 0)).font(.ui(12)).foregroundStyle(Theme.text.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 6) {
                if done { Image(systemName: "checkmark").font(.ui(10, .heavy)) }
                Text(app.t(done ? "history.done" : "history.preview"))
            }
            .font(.ui(12, .bold))
            .foregroundStyle(done ? Theme.greenInk : Theme.text.opacity(0.75))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(done ? AnyShapeStyle(Theme.greenGradient) : AnyShapeStyle(Color.black.opacity(0.25))))
            Text(s.sizeBytes > 0 ? app.size(s.sizeBytes) : "—").font(.ui(15, .bold)).monospacedDigit()
                .foregroundStyle(done ? Theme.green : Theme.text).frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, 18).frame(height: 62)
        .glassCard(highlighted: done ? Theme.green : nil)
    }

    /// "23:42" today, "12.11, 23:42" otherwise: always one line.
    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: app.language == .uk ? "uk_UA" : "en_US")
        f.setLocalizedDateFormatFromTemplate(Calendar.current.isDateInToday(d) ? "jj:mm" : "ddMM jj:mm")
        return f.string(from: d)
    }

    private func symbol(_ command: String) -> String {
        switch command {
        case "clean": return "square.stack.3d.up"
        case "purge": return "folder.badge.gearshape"
        case "optimize": return "bolt"
        case "uninstall": return "trash"
        case "installer": return "arrow.down.to.line"
        default: return "terminal"
        }
    }
    private func name(_ command: String) -> String {
        let key = "history.cmd." + command
        let v = app.t(key)
        return v == key ? command : v
    }
}

// MARK: - Mole missing

struct MissingMoleView: View {
    @EnvironmentObject var app: AppModel
    var body: some View {
        VStack(spacing: 18) {
            BigTile(symbol: "exclamationmark.triangle.fill", size: 96)
            Text(app.t("missing.title")).font(.ui(28, .heavy))
            Text(app.t("missing.body")).foregroundStyle(Theme.secondary).multilineTextAlignment(.center).frame(maxWidth: 460)
            Text("brew install mole").font(.mono(15))
                .padding(.horizontal, 18).padding(.vertical, 10).glassCard(radius: 12)
                .textSelection(.enabled)
            Button(app.t("missing.copy")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("brew install mole", forType: .string)
            }
            .buttonStyle(PrimaryButtonStyle(large: false))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Links into macOS

enum SystemLink {
    case about, battery, storage, softwareUpdate, activityMonitor

    func open() {
        switch self {
        case .activityMonitor:
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"),
                                               configuration: NSWorkspace.OpenConfiguration())
        default:
            let id: String = [
                .about: "com.apple.SystemProfiler.AboutExtension",
                .battery: "com.apple.Battery-Settings.extension",
                .storage: "com.apple.settings.Storage",
                .softwareUpdate: "com.apple.Software-Update-Settings.extension"
            ][self]!
            if let url = URL(string: "x-apple.systempreferences:" + id) { NSWorkspace.shared.open(url) }
        }
    }
}

/// A "This Mac" tile that opens the matching System Settings pane.
struct SpecTile: View {
    let title: String
    let value: String
    let link: SystemLink
    @State private var hover = false

    var body: some View {
        Button { link.open() } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.ui(12)).foregroundStyle(hover ? Theme.accent : Theme.text.opacity(0.62))
                    Spacer()
                    Image(systemName: "arrow.up.forward").font(.ui(10, .bold))
                        .foregroundStyle(Theme.accent).opacity(hover ? 1 : 0)
                }
                Text(value).font(.ui(16, .bold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassCard(radius: 14, highlighted: hover ? Theme.accent : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}

// MARK: - Rotating tips

/// Cyan tips under "This Mac", one every 10 seconds.
struct TipsTicker: View {
    @EnvironmentObject var app: AppModel
    @State private var index = 0
    private let count = 7
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: index == 0 ? "gauge.with.dots.needle.67percent" : "lightbulb.max")
                        .font(.ui(15, .semibold))
                    (Text(index == 0 ? app.t("tips.label.score", app.status.snapshot?.healthScore ?? 100) : app.t("tips.label")).fontWeight(.bold) + Text("  " + app.t("tip.\(index)")))
                        .font(.ui(15))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.accent)
                .shadow(color: Theme.accent.opacity(0.35), radius: 8)
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .clipped()
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule().fill(i == index ? Theme.accent : .white.opacity(0.18))
                        .frame(width: i == index ? 18 : 6, height: 6)
                        .onTapGesture { withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { index = i } }
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity, alignment: .center)
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { index = (index + 1) % count }
        }
    }
}
