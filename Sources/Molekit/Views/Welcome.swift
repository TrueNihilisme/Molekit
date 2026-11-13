import SwiftUI

/// Ring before the first scan: a comet arc orbits and the mark draws itself.
struct IdleRing: View {
    var size: CGFloat = 290
    var lineWidth: CGFloat = 14
    @State private var spin = false
    @State private var draw: CGFloat = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.06), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(AngularGradient(colors: [Theme.accent.opacity(0), Theme.accentDeep, Theme.accent],
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(108)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .shadow(color: Theme.accent.opacity(0.45), radius: 12)
                .rotationEffect(.degrees(spin ? 270 : -90))
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x1D2A42), Color(hex: 0x0E1626)], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: size * 0.42))
                .padding(lineWidth / 2)
            ZStack {
                MoleMark().trim(from: 0, to: draw)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                MoleDot().fill(Theme.accent).opacity(draw > 0.95 ? 1 : 0).scaleEffect(draw > 0.95 ? 1 : 0.2)
            }
            .frame(width: size * 0.42, height: size * 0.42)
            .shadow(color: Theme.accent.opacity(pulse ? 0.7 : 0.35), radius: pulse ? 18 : 10)
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
        .background(
            Circle().fill(RadialGradient(colors: [Theme.accent.opacity(pulse ? 0.26 : 0.14), .clear], center: .center,
                                         startRadius: size * 0.3, endRadius: size * 0.62))
                .frame(width: size + 36, height: size + 36)
        )
        .onAppear {
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 1.4).delay(0.2)) { draw = 1 }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(1.4)) { pulse = true }
        }
    }
}

/// Right side before the first scan, in the spirit of the iOS "hello" screen.
struct WelcomePanel: View {
    @EnvironmentObject var app: AppModel
    @State private var step = 0
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            FullDiskAccessBanner(model: app.permissions)
            VStack(alignment: .leading, spacing: -6) {
                line("Small mole.", visible: step >= 1)
                line("Big cleanup.", visible: step >= 2)
            }
            VStack(alignment: .leading, spacing: 14) {
                feature("square.stack.3d.up", app.t("welcome.f1"), visible: step >= 3)
                feature("hammer", app.t("welcome.f2"), visible: step >= 4)
                feature("lock.shield", app.t("welcome.f3"), visible: step >= 5)
            }
            Spacer(minLength: 0)
            HStack(spacing: 18) {
                Spacer(minLength: 0)
                MoleMascot(mood: .peeking).frame(width: 200, height: 180)
                Text(app.t("welcome.begin"))
                    .font(.ui(28, .heavy))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0x7CEFFF), Theme.accent], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.accent.opacity(0.4), radius: 12)
                Spacer(minLength: 0)
            }
            .opacity(step >= 6 ? 1 : 0)
            .offset(y: step >= 6 ? 0 : 30)
            .padding(.bottom, 12)
        }
        .padding(.top, 44).padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCard(radius: 22)
        .onAppear {
            for i in 1...6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 * Double(i)) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { step = i }
                }
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false).delay(0.8)) { shimmer = true }
        }
    }

    private func line(_ text: String, visible: Bool) -> some View {
        let font = Font.ui(60, .heavy)
        return Text(text)
            .font(font).tracking(-1.8)
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0x7CEFFF), Theme.accent, Theme.accentDeep],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                // a white glint sweeping across the letters
                LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 110)
                    .rotationEffect(.degrees(18))
                    .offset(x: shimmer ? 520 : -520)
                    .mask(Text(text).font(font).tracking(-1.8))
            )
            .shadow(color: Theme.accent.opacity(0.35), radius: 18)
            .fixedSize()
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .blur(radius: visible ? 0 : 6)
    }

    private func feature(_ symbol: String, _ text: String, visible: Bool) -> some View {
        HStack(spacing: 14) {
            GlyphTile(symbol: symbol, size: 40)
            Text(text).font(.ui(15, .medium)).foregroundStyle(Theme.text.opacity(0.85))
        }
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -14)
    }
}
