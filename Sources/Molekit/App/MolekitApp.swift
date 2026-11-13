import SwiftUI

@main
struct MolekitApp: App {
    @StateObject private var app = AppModel()

    init() { Fonts.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .frame(minWidth: 1180, minHeight: 760)
                .preferredColorScheme(.dark)
                .onAppear { if DemoShots.isActive { DemoShots.run(app) } }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 800)
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            ZStack {
                if app.cli == nil && !DemoShots.isActive {
                    MissingMoleView()
                } else {
                    content
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(Theme.text)
        .background {
            ZStack {
                Theme.backdrop
                LinearGradient(colors: [Color(hex: 0x16202F).opacity(0.55), Color(hex: 0x0B111D).opacity(0.7)], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder private var content: some View {
        switch app.tab {
        case .clean: CleanView(model: app.clean)
        case .overview: OverviewView(status: app.status, clean: app.clean, purge: app.purge, history: app.history)
        case .tools:
            switch app.toolScreen {
            case .purge?: PurgeView(model: app.purge)
            case .uninstall?: UninstallView(tools: app.tools)
            case .optimize?: OptimizeView(tools: app.tools)
            case .slim?: SlimView(tools: app.tools)
            case .installer?: InstallerView(tools: app.tools)
            case nil: ToolsView(tools: app.tools, purge: app.purge)
            }
        case .disk: DiskView(model: app.disk)
        case .status: StatusView(model: app.status)
        case .history: HistoryView(model: app.history)
        }
    }
}
