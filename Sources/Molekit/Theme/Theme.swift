import SwiftUI
import CoreText

/// Visual language from the approved mockup:
/// cyan = action/value, green = live/done, red = stop/danger. Light comes from above:
/// surfaces are lighter on top with a thin highlight edge and a soft shadow below.
enum Theme {
    static let accent = Color(hex: 0x40E0FF)
    static let accentDeep = Color(hex: 0x1F8CFF)
    static let green = Color(hex: 0x5FE3A5)
    static let greenTop = Color(hex: 0x6FF0B8)
    static let greenBottom = Color(hex: 0x22C47F)
    static let red = Color(hex: 0xFF6B6B)
    static let text = Color(hex: 0xEEF3FA)
    static let secondary = Color(hex: 0xEEF3FA).opacity(0.66)
    static let tertiary = Color(hex: 0xEEF3FA).opacity(0.5)
    static let tileTop = Color(hex: 0x1C2A44)
    static let tileBottom = Color(hex: 0x0B1424)
    static let ink = Color(hex: 0x04263A)
    static let greenInk = Color(hex: 0x05301D)

    /// Desktop-like backdrop behind the glass window.
    static var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x10192C), Color(hex: 0x0B1322), Color(hex: 0x070C16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 0.25, green: 0.78, blue: 1).opacity(0.30), .clear],
                           center: UnitPoint(x: 0.88, y: -0.12), startRadius: 0, endRadius: 700)
            RadialGradient(colors: [Color(red: 0.12, green: 0.43, blue: 1).opacity(0.30), .clear],
                           center: UnitPoint(x: -0.08, y: 1.12), startRadius: 0, endRadius: 650)
            LinearGradient(stops: [.init(color: .clear, location: 0.38),
                                   .init(color: Color(red: 0.55, green: 0.78, blue: 1).opacity(0.07), location: 0.47),
                                   .init(color: .clear, location: 0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static let cyanGradient = LinearGradient(colors: [Color(hex: 0x74ECFF), Color(hex: 0x1FA8F0)], startPoint: .top, endPoint: .bottom)
    static let greenGradient = LinearGradient(colors: [greenTop, greenBottom], startPoint: .top, endPoint: .bottom)
    static let barGradient = LinearGradient(colors: [accentDeep, accent], startPoint: .leading, endPoint: .trailing)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Surfaces

struct GlassCard: ViewModifier {
    var radius: CGFloat = 16
    var highlighted: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [(highlighted ?? .white).opacity(highlighted == nil ? 0.075 : 0.13),
                                                  (highlighted ?? .white).opacity(highlighted == nil ? 0.035 : 0.05)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder((highlighted ?? .white).opacity(highlighted == nil ? 0.08 : 0.32), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // thin light edge on top
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.30), radius: 11, y: 6)
    }
}

extension View {
    func glassCard(radius: CGFloat = 16, highlighted: Color? = nil) -> some View {
        modifier(GlassCard(radius: radius, highlighted: highlighted))
    }
}

/// Dark glossy app-icon tile with a glowing cyan glyph (SF Symbol).
struct GlyphTile: View {
    let symbol: String
    var size: CGFloat = 42
    var tint: Color = Theme.accent
    var dimmed = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: [Theme.tileTop, Theme.tileBottom], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.ui(size * 0.46, .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.55), radius: size * 0.12)
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.45), radius: size * 0.15, y: size * 0.12)
            .opacity(dimmed ? 0.45 : 1)
    }
}

/// Green glossy checkbox from the mockup.
struct GreenCheckbox: View {
    @Binding var isOn: Bool
    var label: String

    var body: some View {
        Button { isOn.toggle() } label: {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isOn ? AnyShapeStyle(Theme.greenGradient) : AnyShapeStyle(Color.black.opacity(0.25)))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isOn ? Color.white.opacity(0.35) : Color.white.opacity(0.28), lineWidth: isOn ? 0.5 : 1.5)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.ui(12, .heavy))
                        .foregroundStyle(Theme.greenInk)
                        .opacity(isOn ? 1 : 0)
                )
                .frame(width: 24, height: 24)
                .shadow(color: isOn ? Theme.greenBottom.opacity(0.35) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Small round status mark used while scanning/cleaning.
struct StatusMark: View {
    enum Kind { case done, busy, waiting, skipped }
    let kind: Kind

    var body: some View {
        ZStack {
            switch kind {
            case .done:
                Circle().fill(Theme.greenGradient)
                Image(systemName: "checkmark").font(.ui(11, .heavy)).foregroundStyle(Theme.greenInk)
            case .busy:
                Circle().fill(Theme.green.opacity(0.16))
                Circle().strokeBorder(Theme.green, lineWidth: 2)
                Circle().fill(Theme.green).frame(width: 6, height: 6)
            case .waiting:
                Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1.5)
            case .skipped:
                Circle().fill(.white.opacity(0.06))
                Image(systemName: "minus").font(.ui(10, .bold)).foregroundStyle(Theme.tertiary)
            }
        }
        .frame(width: 24, height: 24)
        .shadow(color: kind == .busy ? Theme.green.opacity(0.55) : (kind == .done ? Theme.greenBottom.opacity(0.35) : .clear), radius: 6)
    }
}

/// Pill with a glowing dot ("● Live", "● Ready to clean").
struct LiveChip: View {
    let text: String
    var color: Color = Theme.green

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8).shadow(color: color, radius: 5)
            Text(text).font(.ui(13, .semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.10)))
        .overlay(Capsule().strokeBorder(color.opacity(0.30), lineWidth: 1))
        .shadow(color: color.opacity(0.18), radius: 9)
    }
}

// MARK: - Buttons
// Hover is tracked in a small View (HoverBody); ButtonStyle itself cannot hold state reliably.

struct PrimaryButtonStyle: ButtonStyle {
    var large = true
    func makeBody(configuration: Configuration) -> some View {
        HoverBody { hover in
            configuration.label
                .font(.ui(large ? 18 : 14, .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, large ? 40 : 20)
                .frame(height: large ? 58 : 40)
                .background(Capsule().fill(LinearGradient(colors: hover ? [Color(hex: 0x9AF4FF), Color(hex: 0x33BDF6)] : [Color(hex: 0x74ECFF), Color(hex: 0x1FA8F0)],
                                                          startPoint: .top, endPoint: .bottom)))
                .overlay(Capsule().strokeBorder(.white.opacity(hover ? 0.6 : 0.35), lineWidth: 1))
                .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.2 : (hover ? 0.6 : 0.38)), radius: hover ? 22 : 17, y: hover ? 12 : 10)
                .scaleEffect(configuration.isPressed ? 0.96 : (hover ? 1.03 : 1))
                .brightness(configuration.isPressed ? -0.08 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.18), value: hover)
        }
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverBody { hover in
            configuration.label
                .font(.ui(13, .semibold))
                .foregroundStyle(hover ? Theme.accent : Theme.text)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(Capsule().fill(LinearGradient(colors: hover ? [Theme.accent.opacity(0.24), Theme.accent.opacity(0.10)] : [.white.opacity(0.10), .white.opacity(0.04)],
                                                          startPoint: .top, endPoint: .bottom)))
                .overlay(Capsule().strokeBorder(hover ? Theme.accent.opacity(0.5) : .white.opacity(0.14), lineWidth: 1))
                .shadow(color: hover ? Theme.accent.opacity(0.3) : .black.opacity(0.3), radius: hover ? 12 : 8, y: 6)
                .scaleEffect(configuration.isPressed ? 0.96 : (hover ? 1.03 : 1))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.18), value: hover)
        }
    }
}

/// Neutral glass "Stop" that turns red on hover.
struct StopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverBody { hover in
            configuration.label
                .font(.ui(18, .bold))
                .foregroundStyle(hover ? Color.white : Theme.text)
                .padding(.horizontal, 40)
                .frame(height: 58)
                .background(
                    Capsule().fill(hover
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF7676), Color(hex: 0xD9363F)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom)))
                )
                .overlay(Capsule().strokeBorder(hover ? Color(hex: 0xFFAAAA).opacity(0.6) : Theme.red.opacity(0.28), lineWidth: 1))
                .shadow(color: hover ? Theme.red.opacity(0.45) : .black.opacity(0.35), radius: 15, y: 8)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: hover)
        }
    }
}

struct HoverBody<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content
    @State private var hover = false
    var body: some View {
        content(hover).onHover { hover = $0 }
    }
}

// MARK: - Type

extension Font {
    /// Inter (bundled, SIL OFL 1.1) for all interface text, as in the design.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter Variable", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum Fonts {
    /// Registers the bundled Inter for this process only.
    static func register() {
        guard let url = Bundle.module.url(forResource: "InterVariable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
