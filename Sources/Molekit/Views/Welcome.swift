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
        VStack(alignment: .leading, spacing: 26) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                line("Small mole.", visible: step >= 1)
                line("Big cleanup.", visible: step >= 2)
            }
            VStack(alignment: .leading, spacing: 14) {
                feature("square.stack.3d.up", app.t("welcome.f1"), visible: step >= 3)
                feature("hammer", app.t("welcome.f2"), visible: step >= 4)
                feature("lock.shield", app.t("welcome.f3"), visible: step >= 5)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCard(radius: 22)
        .onAppear {
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 * Double(i)) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { step = i }
                }
            }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) { shimmer = true }
        }
    }

    private func line(_ text: String, visible: Bool) -> some View {
        Text(text)
            .font(.ui(46, .heavy)).tracking(-1.2)
            .foregroundStyle(Theme.text.opacity(0.18))
            .overlay(
                LinearGradient(stops: [.init(color: Theme.accent, location: 0),
                                       .init(color: .white, location: 0.45),
                                       .init(color: Theme.accentDeep, location: 0.9)],
                               startPoint: .leading, endPoint: .trailing)
                    .offset(x: shimmer ? 240 : -240)
                    .mask(Text(text).font(.ui(46, .heavy)).tracking(-1.2))
            )
            .shadow(color: Theme.accent.opacity(0.25), radius: 14)
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
