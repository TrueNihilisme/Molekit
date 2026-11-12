import SwiftUI
import MoleKitCore

/// The Molekit mark: one tunnel line writing "m", the mole as a dot at the end.
struct MoleMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(10, 50)); path.addLine(to: p(10, 30))
        path.addArc(center: p(18, 30), radius: 8 * s, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: p(26, 50))
        path.move(to: p(26, 30))
        path.addArc(center: p(34, 30), radius: 8 * s, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: p(42, 44))
        path.addArc(center: p(48, 44), radius: 6 * s, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        return path
    }
}

/// The dot (the mole) at the end of the tunnel.
struct MoleDot: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        return Path(ellipseIn: CGRect(x: rect.minX + (54 - 5) * s, y: rect.minY + (36 - 5) * s, width: 10 * s, height: 10 * s))
    }
}

struct MoleLogo: View {
    var size: CGFloat = 42
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x7CEFFF), Color(hex: 0x1FB4F0)], startPoint: .top, endPoint: .bottom))
            .overlay(
                ZStack {
                    MoleMark().stroke(Color(hex: 0x06303E), style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round, lineJoin: .round))
                    MoleDot().fill(Color(hex: 0x06303E))
                }
                .frame(width: size * 0.66, height: size * 0.66)
            )
            .frame(width: size, height: size)
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 8)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var app: AppModel
    @State private var moVersion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear.frame(height: 30) // room for the window buttons
            HStack(spacing: 12) {
                MoleLogo()
                VStack(alignment: .leading, spacing: 1) {
                    Text("Molekit").font(.system(size: 17, weight: .bold))
                    Text("System Cleaner").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 6).padding(.bottom, 22)

            ForEach(Tab.allCases) { tab in
                navButton(tab)
            }
            Spacer()
            languageToggle
            HStack(spacing: 12) {
                Text("i").font(.system(size: 13, weight: .heavy))
                    .frame(width: 26, height: 26).background(Circle().fill(.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.t("sidebar.version", moVersion.isEmpty ? "—" : moVersion))
                    Text("Homebrew")
                }
                .font(.system(size: 12)).foregroundStyle(Theme.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .glassCard(radius: 12)
        }
        .padding(.horizontal, 14).padding(.bottom, 16)
        .frame(width: 236)
        .frame(maxHeight: .infinity)
        .background(LinearGradient(colors: [.white.opacity(0.055), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.07)).frame(width: 1) }
        .task {
            if let out = try? await app.cli?.run(["--version"]),
               let line = out.stdout.split(separator: "\n").first(where: { $0.contains("version") }) {
                moVersion = line.components(separatedBy: " ").last ?? ""
            }
        }
    }

    private func navButton(_ tab: Tab) -> some View {
        NavItem(title: app.t(tab.key), symbol: tab.symbol, on: app.tab == tab) {
            app.tab = tab
            app.showPurge = false
        }
    }

    private var languageToggle: some View {
        HStack(spacing: 4) {
            LangButton(title: "UA", on: app.language == .uk) { app.language = .uk }
            LangButton(title: "EN", on: app.language == .en) { app.language = .en }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .padding(.top, 4).padding(.bottom, 8)
    }
}

/// Sidebar item. Active: solid cyan. Others: neutral glass (like the Stop button)
/// that fades to cyan glass on hover.
struct NavItem: View {
    let title: String
    let symbol: String
    let on: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).frame(width: 22)
                    .foregroundStyle(on ? Theme.ink : (hover ? Theme.accent : Color(hex: 0x7EA6D8)))
                    .shadow(color: hover && !on ? Theme.accent.opacity(0.6) : .clear, radius: 5)
                Text(title).font(.system(size: 15, weight: on ? .bold : .medium))
                    .foregroundStyle(on ? Theme.ink : (hover ? Theme.accent : Theme.text.opacity(0.86)))
                Spacer()
            }
            .padding(.horizontal, 14).frame(height: 46)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.18), value: hover)
        .animation(.easeOut(duration: 0.18), value: on)
    }

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        let fill: LinearGradient
        let border: Color
        if on {
            fill = LinearGradient(colors: [Color(hex: 0x6AE9FF), Color(hex: 0x22B6F0)], startPoint: .top, endPoint: .bottom)
            border = .white.opacity(0.35)
        } else if hover {
            fill = LinearGradient(colors: [Theme.accent.opacity(0.24), Theme.accent.opacity(0.10)], startPoint: .top, endPoint: .bottom)
            border = Theme.accent.opacity(0.45)
        } else {
            fill = LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.025)], startPoint: .top, endPoint: .bottom)
            border = .white.opacity(0.08)
        }
        return shape.fill(fill)
            .overlay(shape.strokeBorder(border, lineWidth: 1))
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(on ? 0 : 0.08), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
            .shadow(color: on ? Theme.accent.opacity(0.32) : (hover ? Theme.accent.opacity(0.22) : .black.opacity(0.25)), radius: on ? 11 : 8, y: on ? 8 : 4)
    }
}

/// One half of the UA/EN switch: the active language glows cyan.
struct LangButton: View {
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(on ? Theme.accent : Theme.text.opacity(0.6))
                .shadow(color: on ? Theme.accent.opacity(0.5) : .clear, radius: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(background)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var background: some View {
        if on {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.24), Theme.accent.opacity(0.10)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1))
        }
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double            // 0...1
    var size: CGFloat = 290
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.06), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(AngularGradient(colors: [Theme.accentDeep, Theme.accent], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accent.opacity(0.35), radius: 14)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x1D2A42), Color(hex: 0x0E1626)], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: size * 0.42))
                .padding(lineWidth / 2)
                .overlay(
                    Circle()
                        .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.08), Color.clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                        .padding(lineWidth / 2)
                )
            // glowing head at the end of the arc
            if progress > 0.005 {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(hex: 0x9FF3FF), Theme.accent], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 9))
                    .frame(width: 18, height: 18)
                    .shadow(color: Theme.accent, radius: 9)
                    .offset(y: -(size - lineWidth) / 2)
                    .rotationEffect(.degrees(360 * progress))
            }
        }
        // the stroke is centred on the circle's edge, so the head sits exactly on it
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
        .background(
            Circle().fill(RadialGradient(colors: [Theme.accent.opacity(0.22), .clear], center: .center, startRadius: size * 0.3, endRadius: size * 0.62))
                .frame(width: size + 36, height: size + 36)
        )
    }
}

// MARK: - Disk bar

struct DiskBar: View {
    @EnvironmentObject var app: AppModel
    var extraFree: Int64 = 0
    @State private var space = DiskSpace.root()

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "internaldrive.fill").foregroundStyle(Color(hex: 0x7EA6D8))
            if let space {
                Text(app.t("disk.freeOf", app.size(space.free), app.size(space.total)))
                    .font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.88)).lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.35))
                        Capsule().fill(Theme.barGradient)
                            .frame(width: geo.size.width * CGFloat(Double(space.total - space.free) / Double(max(space.total, 1))))
                            .shadow(color: Theme.accent.opacity(0.6), radius: 5)
                    }
                }
                .frame(height: 7)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .glassCard()
        .onAppear { space = DiskSpace.root() }
        .onChange(of: extraFree) { _, _ in space = DiskSpace.root() }
    }
}

// MARK: - Page header

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 34, weight: .heavy)).tracking(-0.6)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            trailing
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Large dark glossy tile with a glowing symbol, used on Tools and Overview cards.
struct BigTile: View {
    let symbol: String
    var size: CGFloat = 80
    var body: some View {
        GlyphTile(symbol: symbol, size: size)
    }
}

// MARK: - Treemap layout

enum Squarify {
    /// Squarified treemap (Bruls et al.). Returns one rect per value, in input order.
    static func layout(_ values: [Double], in rect: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else { return values.map { _ in .zero } }
        let scale = rect.width * rect.height / total
        let areas = values.map { $0 * scale }
        var out = [CGRect](repeating: .zero, count: values.count)
        var r = rect, i = 0

        func worst(_ row: [Double], _ side: Double) -> Double {
            let s = row.reduce(0, +)
            return row.map { max(side * side * $0 / (s * s), s * s / (side * side * $0)) }.max() ?? .infinity
        }
        while i < areas.count {
            let side = Double(min(r.width, r.height))
            var row = [areas[i]]
            var j = i + 1
            while j < areas.count, worst(row + [areas[j]], side) <= worst(row, side) { row.append(areas[j]); j += 1 }
            let s = row.reduce(0, +)
            if r.width >= r.height {
                let w = s / Double(r.height); var y = Double(r.minY)
                for (k, a) in row.enumerated() { let h = a / w; out[i + k] = CGRect(x: Double(r.minX), y: y, width: w, height: h); y += h }
                r = CGRect(x: r.minX + w, y: r.minY, width: r.width - w, height: r.height)
            } else {
                let h = s / Double(r.width); var x = Double(r.minX)
                for (k, a) in row.enumerated() { let w = a / h; out[i + k] = CGRect(x: x, y: Double(r.minY), width: w, height: h); x += w }
                r = CGRect(x: r.minX, y: r.minY + h, width: r.width, height: r.height - h)
            }
            i = j
        }
        return out
    }
}
