import SwiftUI

/// The cyan mole, drawn in code and animated per cleaning phase.
struct MoleMascot: View {
    enum Mood { case digging, peeking, cleaning, happy }
    let mood: Mood

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                draw(&ctx, size: size, t: t)
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let groundY = h * 0.80
        let cx = w * 0.5
        let r = min(w * 0.17, h * 0.34)                    // head radius
        let cyan = Color(hex: 0x40E0FF)
        let deep = Color(hex: 0x1F8CFF)
        let ink = Color(hex: 0x06303E)

        // how far the mole sticks out of the hole, and how it moves
        var rise: Double, sway: Double = 0
        switch mood {
        case .digging: rise = 0.55 + 0.25 * abs(sin(t * 4.2)); sway = sin(t * 4.2) * 4
        case .cleaning: rise = 0.65 + 0.12 * abs(sin(t * 8)); sway = sin(t * 8) * 3
        case .peeking: rise = 0.92 + 0.03 * sin(t * 1.6)
        case .happy: rise = 1.0 + 0.10 * abs(sin(t * 3.2))
        }
        let headY = groundY - r * rise

        // glow behind
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 2, y: groundY - r * 2.2, width: r * 4, height: r * 3)),
                 with: .radialGradient(Gradient(colors: [cyan.opacity(0.18), .clear]), center: CGPoint(x: cx, y: groundY - r * 0.6),
                                       startRadius: 0, endRadius: r * 2))

        // head (clipped by the ground so it rises out of the hole)
        var head = ctx
        head.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: groundY)))
        let headRect = CGRect(x: cx - r + sway, y: headY - r, width: r * 2, height: r * 2.4)
        head.fill(Path(roundedRect: headRect, cornerRadius: r),
                  with: .linearGradient(Gradient(colors: [Color(hex: 0x7CEFFF), cyan, deep]),
                                        startPoint: CGPoint(x: cx, y: headY - r), endPoint: CGPoint(x: cx, y: headY + r * 1.4)))
        // shine
        head.fill(Path(ellipseIn: CGRect(x: cx - r * 0.55 + sway, y: headY - r * 0.8, width: r * 0.6, height: r * 0.32)),
                  with: .color(.white.opacity(0.35)))

        // eyes: blink every ~3.5 s, look around when peeking
        let blink = (t.truncatingRemainder(dividingBy: 3.5)) < 0.14
        let look = mood == .peeking ? sin(t * 0.9) * r * 0.08 : 0
        let eyeY = headY - r * 0.12
        for dx in [-0.36, 0.36] {
            let ex = cx + sway + r * dx + look
            if mood == .happy {
                var p = Path()
                p.move(to: CGPoint(x: ex - r * 0.12, y: eyeY + r * 0.04))
                p.addQuadCurve(to: CGPoint(x: ex + r * 0.12, y: eyeY + r * 0.04), control: CGPoint(x: ex, y: eyeY - r * 0.14))
                head.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: r * 0.07, lineCap: .round))
            } else if blink {
                head.fill(Path(CGRect(x: ex - r * 0.1, y: eyeY - r * 0.015, width: r * 0.2, height: r * 0.04)), with: .color(ink))
            } else {
                head.fill(Path(ellipseIn: CGRect(x: ex - r * 0.085, y: eyeY - r * 0.1, width: r * 0.17, height: r * 0.2)), with: .color(ink))
                head.fill(Path(ellipseIn: CGRect(x: ex - r * 0.02, y: eyeY - r * 0.07, width: r * 0.06, height: r * 0.06)), with: .color(.white.opacity(0.8)))
            }
        }
        // nose and whiskers
        let noseY = headY + r * 0.18
        head.fill(Path(ellipseIn: CGRect(x: cx + sway + look - r * 0.15, y: noseY - r * 0.1, width: r * 0.3, height: r * 0.2)), with: .color(ink))
        for (dx, dir) in [(-0.22, -1.0), (0.22, 1.0)] {
            for dy in [-0.03, 0.08] {
                var p = Path()
                p.move(to: CGPoint(x: cx + sway + r * dx, y: noseY + r * dy))
                p.addLine(to: CGPoint(x: cx + sway + r * (dx + 0.42 * dir), y: noseY + r * (dy + 0.04 * (dy < 0 ? -1 : 1))))
                head.stroke(p, with: .color(ink.opacity(0.6)), lineWidth: r * 0.025)
            }
        }

        // paws on the rim of the hole
        if mood != .digging {
            for dx in [-0.62, 0.62] {
                let px = cx + r * dx + sway * 0.5
                let paw = CGRect(x: px - r * 0.2, y: groundY - r * 0.16, width: r * 0.4, height: r * 0.24)
                ctx.fill(Path(roundedRect: paw, cornerRadius: r * 0.12), with: .color(Color(hex: 0x6FE6FF)))
            }
        }

        // the mound
        var mound = Path()
        mound.move(to: CGPoint(x: cx - r * 2.3, y: groundY + r * 0.25))
        mound.addQuadCurve(to: CGPoint(x: cx + r * 2.3, y: groundY + r * 0.25), control: CGPoint(x: cx, y: groundY - r * 0.55))
        mound.closeSubpath()
        ctx.fill(mound, with: .linearGradient(Gradient(colors: [cyan.opacity(0.35), cyan.opacity(0.08)]),
                                              startPoint: CGPoint(x: cx, y: groundY - r * 0.4), endPoint: CGPoint(x: cx, y: groundY + r * 0.3)))
        // hole
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 1.05, y: groundY - r * 0.12, width: r * 2.1, height: r * 0.3)), with: .color(Color(hex: 0x050B14)))
        // ground line
        ctx.fill(Path(CGRect(x: w * 0.06, y: groundY + r * 0.25, width: w * 0.88, height: 1)), with: .color(cyan.opacity(0.25)))

        // dirt flying while digging / cleaning
        if mood == .digging || mood == .cleaning {
            let speed = mood == .cleaning ? 1.6 : 1.0
            for i in 0..<9 {
                let seed = Double(i) * 1.37
                let period = 1.1 / speed
                let phase = ((t * speed + seed) .truncatingRemainder(dividingBy: period)) / period   // 0...1
                let side = i % 2 == 0 ? -1.0 : 1.0
                let vx = side * (r * (0.9 + 0.6 * sin(seed * 3)))
                let x = cx + side * r * 0.7 + vx * phase
                let y = groundY - r * 0.1 - (r * 1.6 * phase - r * 2.0 * phase * phase)
                let s = r * (0.07 + 0.04 * sin(seed))
                ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)),
                         with: .color(cyan.opacity(0.75 * (1 - phase))))
            }
        }

        // sparkles when done
        if mood == .happy {
            for i in 0..<6 {
                let a = Double(i) / 6 * .pi * 2 + t * 0.6
                let dist = r * (1.7 + 0.15 * sin(t * 2 + Double(i)))
                let px = cx + cos(a) * dist, py = headY - r * 0.2 + sin(a) * dist * 0.6
                let tw = 0.5 + 0.5 * sin(t * 4 + Double(i) * 1.7)
                let s = r * 0.12 * tw
                var star = Path()
                star.move(to: CGPoint(x: px, y: py - s * 2)); star.addLine(to: CGPoint(x: px + s * 0.5, y: py - s * 0.5))
                star.addLine(to: CGPoint(x: px + s * 2, y: py)); star.addLine(to: CGPoint(x: px + s * 0.5, y: py + s * 0.5))
                star.addLine(to: CGPoint(x: px, y: py + s * 2)); star.addLine(to: CGPoint(x: px - s * 0.5, y: py + s * 0.5))
                star.addLine(to: CGPoint(x: px - s * 2, y: py)); star.addLine(to: CGPoint(x: px - s * 0.5, y: py - s * 0.5))
                star.closeSubpath()
                ctx.fill(star, with: .color(Color(hex: 0x6FF0B8).opacity(tw)))
            }
        }
    }
}

/// Card at the bottom of the result list: the mole plus one line about what is happening.
struct MascotCard: View {
    let mood: MoleMascot.Mood
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            MoleMascot(mood: mood).frame(width: 220)
            Text(text)
                .font(.ui(20, .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0x7CEFFF), Theme.accent], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.accent.opacity(0.35), radius: 10)
                .multilineTextAlignment(.leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: text)
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 210)
        .glassCard(radius: 20)
    }
}
