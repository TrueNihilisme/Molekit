import SwiftUI
import MoleKitCore

struct CleanView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var model: CleanModel

    var body: some View {
        HStack(spacing: 22) {
            center.frame(maxWidth: .infinity)
            list.frame(width: 512)
        }
        .padding(.top, 26).padding(.horizontal, 24).padding(.bottom, 22)
        .onAppear { if model.phase == .idle { model.scan() } }
    }

    // MARK: centre column

    private var center: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                LiveChip(text: chipText)
                Text(title).font(.system(size: 38, weight: .heavy)).tracking(-0.8)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            Spacer(minLength: 12)
            ZStack {
                ProgressRing(progress: ringProgress)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: ringProgress)
                VStack(spacing: 2) {
                    if model.phase == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.greenInk)
                            .frame(width: 44, height: 44).background(Circle().fill(Theme.greenGradient))
                            .shadow(color: Theme.greenBottom.opacity(0.4), radius: 9, y: 6)
                            .padding(.bottom, 6)
                    }
                    Text(ringNumber)
                        .font(.system(size: 66, weight: .heavy)).monospacedDigit().tracking(-2)
                        .shadow(color: Theme.accent.opacity(0.25), radius: 12)
                        .contentTransition(.numericText())
                    Text(ringUnit).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text.opacity(0.9)).padding(.top, 6)
                    Text(ringLabel).font(.system(size: 14)).foregroundStyle(Theme.text.opacity(0.6))
                }
            }
            Spacer(minLength: 12)
            VStack(spacing: 18) {
                Text(hint).font(.system(size: 14)).foregroundStyle(Theme.secondary).frame(minHeight: 20)
                    .multilineTextAlignment(.center)
                actionButton
            }
            Spacer(minLength: 12)
            DiskBar(extraFree: model.result?.bytes ?? 0).frame(maxWidth: 470)
        }
    }

    @ViewBuilder private var actionButton: some View {
        switch model.phase {
        case .scanning, .cleaning:
            Button { model.stop() } label: {
                Label(app.t("clean.stop"), systemImage: "stop.circle")
            }
            .buttonStyle(StopButtonStyle())
        case .found:
            Button { model.cleanSelected() } label: {
                Label(app.t("clean.clean"), systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.selectedSections.isEmpty)
            .opacity(model.selectedSections.isEmpty ? 0.5 : 1)
        case .done, .idle, .failed:
            Button { model.scan() } label: {
                Label(app.t(model.phase == .done ? "clean.scanAgain" : "clean.scan"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: right column

    private var list: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                if model.phase == .found {
                    GreenCheckbox(isOn: Binding(get: { model.allSelected }, set: { _ in model.toggleAll() }), label: app.t("clean.selectAll"))
                }
                Text(listHead).font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(app.size(listTotal))
                    .font(.system(size: 19, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Theme.accent).shadow(color: Theme.accent.opacity(0.35), radius: 8)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 18).frame(height: 58)
            .glassCard(radius: 16, highlighted: .white)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if model.sections.isEmpty {
                        placeholderRows
                    } else {
                        ForEach(Array(model.sections.enumerated()), id: \.element.id) { index, section in
                            SectionRow(model: model, section: section, mark: mark(for: section, index: index))
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.never)
        }
    }

    private var placeholderRows: some View {
        ForEach(0..<8, id: \.self) { i in
            HStack(spacing: 12) {
                StatusMark(kind: i == 0 && model.phase == .scanning ? .busy : .waiting)
                GlyphTile(symbol: "magnifyingglass", dimmed: true)
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.08)).frame(width: 160, height: 12)
                Spacer()
                Text(model.phase == .scanning ? app.t("clean.scanningShort") : "")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 16).frame(height: 58)
            .glassCard()
            .opacity(i == 0 ? 1 : 0.7)
        }
    }

    private func mark(for section: CleanPreview.Section, index: Int) -> StatusMark.Kind? {
        let selected = !model.deselected.contains(section.title)
        switch model.phase {
        case .cleaning:
            guard selected else { return .skipped }
            let order = model.selectedSections.firstIndex(where: { $0.id == section.id }) ?? 0
            let done = Int(model.progress * Double(model.selectedSections.count))
            return order < done ? .done : (order == done ? .busy : .waiting)
        case .done:
            return selected ? .done : .skipped
        case .scanning:
            return .done
        default:
            return nil
        }
    }

    // MARK: texts

    private var chipText: String {
        switch model.phase {
        case .idle: return app.t("clean.chip.idle")
        case .scanning: return app.t("clean.chip.scanning", Int(model.progress * 100))
        case .found: return app.t("clean.chip.ready")
        case .cleaning: return app.t("clean.chip.cleaning", Int(model.progress * 100))
        case .done: return app.t("clean.chip.done")
        case .failed: return app.t("clean.chip.failed")
        }
    }

    private var title: String {
        switch model.phase {
        case .idle: return app.t("clean.title.idle")
        case .scanning: return app.t("clean.title.scanning")
        case .found: return model.sections.isEmpty ? app.t("clean.title.nothing") : app.t("clean.title.found")
        case .cleaning: return app.t("clean.title.cleaning")
        case .done: return app.t("clean.title.done")
        case .failed: return app.t("clean.title.failed")
        }
    }

    private var hint: String {
        switch model.phase {
        case .scanning: return model.currentSection.isEmpty ? app.t("clean.hint.starting") : app.t("clean.hint.checking", model.currentSection)
        case .found: return model.deselected.isEmpty ? app.t("clean.hint.found") : app.t("clean.hint.protected")
        case .cleaning: return app.t("clean.hint.cleaning")
        case .done: return "Small mole. Big cleanup."
        case .failed(let message): return message
        case .idle: return app.t("clean.hint.idle")
        }
    }

    private var ringProgress: Double {
        switch model.phase {
        case .found: return model.preview == nil ? 0 : (model.sections.isEmpty ? 0 : Double(model.selectedBytes) / Double(max(model.preview?.total ?? 1, 1)))
        case .done: return 1
        case .idle, .failed: return 0
        default: return model.progress
        }
    }

    private var ringBytes: Int64 {
        switch model.phase {
        case .found: return model.selectedBytes
        case .done: return model.result?.bytes ?? model.selectedBytes
        case .cleaning: return Int64(Double(model.selectedBytes) * model.progress)
        default: return 0
        }
    }

    private var ringNumber: String {
        if model.phase == .scanning { return "\(Int(model.progress * 100))%" }
        let s = app.size(ringBytes)
        return String(s.split(separator: " ").first ?? "0")
    }
    private var ringUnit: String {
        if model.phase == .scanning { return "" }
        return String(app.size(ringBytes).split(separator: " ").last ?? "")
    }
    private var ringLabel: String {
        switch model.phase {
        case .found: return app.t("clean.ring.canFree")
        case .cleaning, .done: return app.t("clean.ring.freed")
        case .scanning: return app.t("clean.ring.scanned")
        default: return ""
        }
    }

    private var listHead: String {
        switch model.phase {
        case .found: return app.t("clean.selectAll")
        case .cleaning: return app.t("clean.list.cleaning")
        case .done: return app.t("clean.list.freed")
        default: return app.t("clean.list.found")
        }
    }
    private var listTotal: Int64 {
        switch model.phase {
        case .done: return model.result?.bytes ?? model.selectedBytes
        default: return model.phase == .found ? model.selectedBytes : (model.preview?.total ?? 0)
        }
    }
}

// MARK: - one category

struct SectionRow: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var model: CleanModel
    let section: CleanPreview.Section
    let mark: StatusMark.Kind?

    private var expanded: Bool { model.expanded.contains(section.id) }
    private var selected: Bool { !model.deselected.contains(section.title) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let mark {
                    StatusMark(kind: mark)
                } else {
                    GreenCheckbox(isOn: Binding(get: { selected }, set: { _ in model.toggle(section.title) }), label: section.title)
                }
                GlyphTile(symbol: SectionStyle.symbol(for: section.title), dimmed: mark == .skipped)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SectionStyle.name(section.title, app: app)).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(rightText).font(.system(size: 14, weight: .bold)).monospacedDigit()
                    .foregroundStyle(rightColor).frame(minWidth: 76, alignment: .trailing)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if expanded { model.expanded.remove(section.id) } else { model.expanded.insert(section.id) }
                    }
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.tertiary).rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(app.t("clean.details"))
            }
            .padding(.leading, 16).padding(.trailing, 8).frame(height: 58)

            if expanded {
                VStack(spacing: 4) {
                    ForEach(section.items) { item in
                        HStack {
                            Text(PathDisplay.tilde(item.path)).font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.secondary).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(app.size(item.bytes)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 12)
            }
        }
        .glassCard(highlighted: mark == .busy ? Theme.green : nil)
        .opacity(mark == .skipped ? 0.7 : 1)
    }

    private var subtitle: String {
        let first = section.items.first.map { PathDisplay.tilde($0.path) } ?? ""
        return section.items.count > 1 ? app.t("clean.moreFolders", first, section.items.count - 1) : first
    }
    private var rightText: String {
        switch mark {
        case .busy?: return app.t("clean.row.cleaning")
        case .skipped?: return app.t("clean.row.skipped")
        default: return app.size(section.bytes)
        }
    }
    private var rightColor: Color {
        switch mark {
        case .done?: return model.phase == .scanning ? Theme.text : Theme.green
        case .busy?: return Theme.green
        case .skipped?: return Theme.tertiary
        default: return Theme.text
        }
    }
}

/// Icons and translated names for Mole's section titles.
enum SectionStyle {
    static func symbol(for title: String) -> String {
        let t = title.lowercased()
        let map: [(String, String)] = [
            ("essential", "square.stack.3d.up"), ("app caches", "square.stack.3d.up.fill"), ("browser", "globe"),
            ("cloud", "cloud"), ("developer", "hammer"), ("virtual", "cube"), ("application support", "folder"),
            ("leftover", "trash"), ("apple silicon", "cpu"), ("backup", "iphone"), ("time machine", "clock.arrow.circlepath"),
            ("large", "doc.zipper"), ("system data", "gearshape"), ("project", "shippingbox"), ("application", "app.badge"),
            ("apps", "app.badge")
        ]
        return map.first { t.contains($0.0) }?.1 ?? "doc"
    }

    @MainActor static func name(_ title: String, app: AppModel) -> String {
        let key = "section." + title
        let value = app.t(key)
        return value == key ? title : value
    }
}
