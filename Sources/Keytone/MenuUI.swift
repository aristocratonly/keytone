import SwiftUI

/// Index-card world, kept quiet for a working panel: light card stock, faint blue rules,
/// typewritten headings, red ribbon ink as the only accent.
/// Russian or English, following the system language.
let isRussian = (Locale.preferredLanguages.first ?? "en").hasPrefix("ru")
func L(_ ru: String, _ en: String) -> String { isRussian ? ru : en }

enum Theme {
    static let card = Color(red: 0.965, green: 0.976, blue: 0.984)
    static let gold = Color(red: 0.953, green: 0.784, blue: 0.361)
    static let rule = Color(red: 0.25, green: 0.47, blue: 0.67).opacity(0.22)
    static let ink = Color(red: 0.118, green: 0.110, blue: 0.102)
    static let inkSoft = Color(red: 0.30, green: 0.29, blue: 0.27)
    static let red = Color(red: 0.769, green: 0.204, blue: 0.169)
    static let tab = Color(red: 0.875, green: 0.914, blue: 0.941)
    static let anim = Animation.easeOut(duration: 0.14)

    static func typed(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Faint ruled lines, like an index card.
struct Ruled: View {
    var spacing: CGFloat = 26
    var body: some View {
        Canvas { ctx, size in
            var y = spacing - 0.5
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Theme.rule))
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

struct MenuView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 16) {
                if !state.hasPermission { permission }

                Section(L("Звук клавиатуры", "Keyboard sound")) {
                    VStack(spacing: 0) {
                        ForEach(state.keyPacks) { p in
                            Row(title: p.name, subtitle: p.subtitle, selected: state.keyProfile == p.id,
                                onDelete: p.isCustom ? { state.remove(p) } : nil) {
                                state.keyProfile = p.id
                                state.preview(p)
                            }
                        }
                        if state.keyPacks.isEmpty {
                            Text(L("Паков пока нет. Импортируйте свой ниже.", "No packs yet. Add your own below."))
                                .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                        }
                    }
                    VolumeRow(icon: "speaker.wave.2.fill", value: $state.keyVolume).padding(.top, 6)
                }

                Section(L("Мышь", "Mouse"), trailing: AnyView(MiniToggle(isOn: $state.mouseEnabled))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Segmented(items: Library.mouse.map { ($0.id, $0.name) }, selection: state.mouseProfile) { id in
                            state.mouseProfile = id
                            if let p = Library.mouse.first(where: { $0.id == id }) { state.preview(p) }
                        }
                        VolumeRow(icon: "computermouse.fill", value: $state.mouseVolume)
                        OptionRow(title: L("Звук прокрутки", "Scroll sound"), isOn: $state.scrollEnabled)
                    }
                    .disabled(!state.mouseEnabled)
                    .opacity(state.mouseEnabled ? 1 : 0.45)
                }

                Section(L("Как звучит", "How it sounds")) {
                    VStack(spacing: 8) {
                        OptionRow(title: L("Звук отпускания", "Release sound"), isOn: $state.playRelease)
                        OptionRow(title: L("Не повторять при удержании", "Don’t repeat while held"), isOn: $state.ignoreRepeat)
                        OptionRow(title: L("Стерео по положению клавиши", "Stereo by key position"), isOn: $state.stereo)
                        HStack {
                            Text(L("Живость тона", "Pitch variation")).font(.system(size: 12.5)).foregroundStyle(Theme.ink)
                            Spacer()
                            Slider(value: $state.pitchVariance, in: 0...1).frame(width: 110).controlSize(.mini)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        FlatButton(title: L("Добавить пак…", "Add pack…"), icon: "plus") { state.importPack() }
                        FlatButton(title: L("Папка паков", "Packs folder"), icon: "folder") { NSWorkspace.shared.open(Library.packsDir) }
                    }
                    if let m = state.importMessage {
                        Text(m).font(.system(size: 11.5)).foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
            .fixedSize(horizontal: false, vertical: true)
            footer
        }
        .frame(width: 320)
        .background(Theme.card)
        .background(alignment: .top) { Ruled().padding(.top, 58) }
        .tint(Theme.red)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        @Bindable var state = state
        return HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Keytone").font(Theme.typed(15, .medium)).foregroundStyle(Theme.ink)
                Text(state.enabled ? (state.currentKeyPack?.name ?? L("Включён", "On")) : L("Выключен — тишина", "Off, silent"))
                    .font(.system(size: 11.5)).foregroundStyle(Theme.inkSoft).lineLimit(1)
                    .contentTransition(.interpolate)
            }
            Spacer()
            MiniToggle(isOn: $state.enabled)
        }
        .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.red).frame(height: 1.5) }
        .animation(Theme.anim, value: state.enabled)
    }

    private var footer: some View {
        @Bindable var state = state
        return HStack {
            Toggle(L("Запускать при входе", "Open at login"), isOn: $state.launchAtLogin)
                .toggleStyle(.checkbox).font(.system(size: 11.5)).foregroundStyle(Theme.inkSoft)
            Spacer()
            Button(L("Выйти", "Quit")) { NSApp.terminate(nil) }
                .buttonStyle(.plain).font(Theme.typed(11.5)).foregroundStyle(Theme.inkSoft)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.tab.opacity(0.6))
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Keytone пока не слышит клавиатуру. Разрешите ему «Мониторинг ввода» в Настройках.", "Keytone can’t hear your keyboard yet. Allow it in Input Monitoring in System Settings."))
                .font(.system(size: 12)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            FlatButton(title: L("Открыть Настройки", "Open System Settings"), icon: "arrow.up.forward", prominent: true) { state.requestPermission() }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 3).fill(Theme.gold))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        .rotationEffect(.degrees(-0.6))
    }
}

// MARK: - Components

/// A typed heading with the card's red rule under it.
struct Section<C: View>: View {
    let title: String
    var trailing: AnyView? = nil
    let content: C
    init(_ title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> C) {
        self.title = title; self.trailing = trailing; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Theme.typed(12, .medium)).foregroundStyle(Theme.red)
                Spacer()
                trailing
            }
            content
        }
    }
}

/// A pack on the card: typed name, red tick when chosen.
struct Row: View {
    let title: String, subtitle: String
    let selected: Bool
    var onDelete: (() -> Void)?
    let action: () -> Void
    @State private var hover = false

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.red)
                .opacity(selected ? 1 : 0)
                .scaleEffect(selected ? 1 : 0.6)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.typed(13, selected ? .semibold : .regular)).foregroundStyle(Theme.ink).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.inkSoft).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let onDelete, hover {
                Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 10.5)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.inkSoft).help(L("Удалить пак", "Remove pack"))
            }
        }
        .padding(.horizontal, 6).frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 3).fill(hover && !selected ? Theme.tab.opacity(0.7) : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }

    var body: some View {
        Button { withAnimation(Theme.anim) { action() } } label: { label }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Mouse sound picker drawn as index tabs: the chosen one is pulled forward.
struct Segmented: View {
    let items: [(String, String)]
    let selection: String
    let onSelect: (String) -> Void
    var body: some View {
        HStack(spacing: 3) {
            ForEach(items, id: \.0) { id, name in
                let on = selection == id
                Button { withAnimation(Theme.anim) { onSelect(id) } } label: {
                    Text(name).font(Theme.typed(12, on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.ink : Theme.inkSoft)
                        .frame(maxWidth: .infinity).frame(height: 24)
                        .background(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                            .fill(on ? Theme.gold : Theme.tab))
                        .offset(y: on ? 0 : 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.gold).frame(height: 2).offset(y: 2) }
        .padding(.bottom, 2)
    }
}

struct VolumeRow: View {
    let icon: String
    @Binding var value: Double
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 10.5)).foregroundStyle(Theme.inkSoft).frame(width: 16)
            Slider(value: $value, in: 0...1).controlSize(.mini)
            Text("\(Int(value * 100))").font(Theme.typed(11)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                .frame(width: 26, alignment: .trailing)
        }
    }
}

struct OptionRow: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Text(title).font(.system(size: 12.5)).foregroundStyle(Theme.ink)
            Spacer()
            MiniToggle(isOn: $isOn)
        }
    }
}

struct MiniToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Toggle("", isOn: $isOn).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(Theme.red)
    }
}

/// Plain card-stock buttons; the prominent one is inked in red like the site's stamp.
struct FlatButton: View {
    let title: String, icon: String
    var prominent = false
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(Theme.typed(11.5, .medium))
            }
            .foregroundStyle(prominent ? Theme.red : Theme.ink)
            .padding(.horizontal, 10).frame(height: 26)
            .frame(maxWidth: prominent ? nil : .infinity)
            .background(RoundedRectangle(cornerRadius: 5).fill(hover ? Theme.tab : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .strokeBorder(prominent ? Theme.red : Theme.inkSoft.opacity(0.35), lineWidth: prominent ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
