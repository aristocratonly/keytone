import SwiftUI

/// Restrained palette: deep navy surfaces, one blue accent, no glow.
enum Theme {
    static let bg = Color(red: 0.047, green: 0.067, blue: 0.118)
    static let surface = Color(red: 0.078, green: 0.105, blue: 0.172)
    static let raised = Color(red: 0.105, green: 0.14, blue: 0.225)
    static let line = Color.white.opacity(0.065)
    static let accent = Color(red: 0.36, green: 0.6, blue: 1.0)
    static let text = Color(red: 0.93, green: 0.95, blue: 0.99)
    static let dim = Color(red: 0.55, green: 0.61, blue: 0.73)
    static let anim = Animation.easeOut(duration: 0.14)
}

struct MenuView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                if !state.hasPermission { permission }

                Section("Звук клавиатуры") {
                    Group {
                        VStack(spacing: 0) {
                            ForEach(Array(state.keyPacks.enumerated()), id: \.element.id) { i, p in
                                if i > 0 { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 34) }
                                Row(title: p.name, subtitle: p.subtitle, selected: state.keyProfile == p.id,
                                    onDelete: p.isCustom ? { state.remove(p) } : nil) {
                                    state.keyProfile = p.id
                                    state.preview(p)
                                }
                            }
                            if state.keyPacks.isEmpty {
                                Text("Нет паков — импортируйте свой ниже").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                        }
                        Divider().overlay(Theme.line)
                        VolumeRow(icon: "speaker.wave.2.fill", value: $state.keyVolume).padding(10)
                    }
                }

                Section("Мышь", trailing: AnyView(MiniToggle(isOn: $state.mouseEnabled))) {
                    Group {
                        Segmented(items: Library.mouse.map { ($0.id, $0.name) }, selection: state.mouseProfile) { id in
                            state.mouseProfile = id
                            if let p = Library.mouse.first(where: { $0.id == id }) { state.preview(p) }
                        }
                        .padding(8)
                        Divider().overlay(Theme.line)
                        VolumeRow(icon: "computermouse.fill", value: $state.mouseVolume).padding(.horizontal, 10).padding(.vertical, 8)
                        Divider().overlay(Theme.line)
                        OptionRow(title: "Звук колеса", isOn: $state.scrollEnabled).padding(.horizontal, 10).padding(.vertical, 8)
                    }
                    .disabled(!state.mouseEnabled)
                    .opacity(state.mouseEnabled ? 1 : 0.45)
                }

                Section("Параметры") {
                    Group {
                        OptionRow(title: "Звук отпускания", isOn: $state.playRelease).padding(.horizontal, 10).padding(.vertical, 8)
                        Divider().overlay(Theme.line)
                        OptionRow(title: "Игнорировать автоповтор", isOn: $state.ignoreRepeat).padding(.horizontal, 10).padding(.vertical, 8)
                        Divider().overlay(Theme.line)
                        OptionRow(title: "Стерео-панорама", isOn: $state.stereo).padding(.horizontal, 10).padding(.vertical, 8)
                        Divider().overlay(Theme.line)
                        HStack {
                            Text("Живость тона").font(.system(size: 12)).foregroundStyle(Theme.text)
                            Spacer()
                            Slider(value: $state.pitchVariance, in: 0...1).frame(width: 118).controlSize(.mini)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        FlatButton(title: "Импорт пака", icon: "plus") { state.importPack() }
                        FlatButton(title: "Папка", icon: "folder") { NSWorkspace.shared.open(Library.packsDir) }
                    }
                    if let m = state.importMessage {
                        Text(m).font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                }
            }
            .padding(12)
            .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Theme.line)
            footer
        }
        .frame(width: 320)
        .background(Theme.bg)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        @Bindable var state = state
        return HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Keytone").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.text)
                HStack(spacing: 5) {
                    Circle().fill(state.enabled ? Color(red: 0.32, green: 0.86, blue: 0.62) : Theme.dim).frame(width: 6, height: 6)
                    Text(state.enabled ? (state.currentKeyPack?.name ?? "Включено") : "Выключено")
                        .font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(1)
                }
            }
            Spacer()
            MiniToggle(isOn: $state.enabled)
        }
        .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 11)
        .background(LinearGradient(colors: [Theme.raised.opacity(0.7), Theme.bg], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var footer: some View {
        @Bindable var state = state
        return HStack {
            Toggle("Запуск при входе", isOn: $state.launchAtLogin)
                .toggleStyle(.checkbox).font(.system(size: 11)).foregroundStyle(Theme.dim)
            Spacer()
            Button("Выйти") { NSApp.terminate(nil) }
                .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dim)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var permission: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(Theme.accent).padding(.top, 1)
            VStack(alignment: .leading, spacing: 7) {
                Text("Разрешите «Мониторинг ввода», чтобы Keytone слышал клавиатуру.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                FlatButton(title: "Открыть настройки", icon: "arrow.up.forward", prominent: true) { state.requestPermission() }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent.opacity(0.28)))
    }
}

// MARK: - Components

/// Titled group: small caps label above a rounded card.
struct Section<C: View>: View {
    let title: String
    var trailing: AnyView? = nil
    let content: C
    init(_ title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> C) {
        self.title = title; self.trailing = trailing; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.7).foregroundStyle(Theme.dim)
                Spacer()
                trailing
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct Row: View {
    let title: String, subtitle: String
    let selected: Bool
    var onDelete: (() -> Void)?
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().strokeBorder(selected ? Theme.accent : Theme.dim.opacity(0.5), lineWidth: 1.5).frame(width: 14, height: 14)
                if selected { Circle().fill(Theme.accent).frame(width: 7, height: 7).transition(.scale) }
            }
            .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: selected ? .semibold : .regular)).foregroundStyle(Theme.text).lineLimit(1)
                Text(subtitle).font(.system(size: 10.5)).foregroundStyle(Theme.dim).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let onDelete, hover {
                Button(action: onDelete) { Image(systemName: "trash").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(selected ? Theme.accent.opacity(0.1) : (hover ? Color.white.opacity(0.03) : .clear))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.anim) { action() } }
        .onHover { hover = $0 }
    }
}

struct Segmented: View {
    let items: [(String, String)]
    let selection: String
    let onSelect: (String) -> Void
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.0) { id, name in
                Text(name).font(.system(size: 11.5, weight: selection == id ? .semibold : .regular))
                    .foregroundStyle(selection == id ? Theme.text : Theme.dim)
                    .frame(maxWidth: .infinity).frame(height: 24)
                    .background {
                        if selection == id {
                            RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.24))
                                .matchedGeometryEffect(id: "seg", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(Theme.anim) { onSelect(id) } }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
    }
}

struct VolumeRow: View {
    let icon: String
    @Binding var value: Double
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 10.5)).foregroundStyle(Theme.dim).frame(width: 16)
            Slider(value: $value, in: 0...1).controlSize(.mini)
            Text("\(Int(value * 100))").font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.dim).frame(width: 24, alignment: .trailing)
        }
    }
}

struct OptionRow: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text)
            Spacer()
            MiniToggle(isOn: $isOn)
        }
    }
}

struct MiniToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Toggle("", isOn: $isOn).toggleStyle(.switch).controlSize(.mini).labelsHidden().tint(Theme.accent)
    }
}

struct FlatButton: View {
    let title: String, icon: String
    var prominent = false
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(prominent ? .white : Theme.text)
            .padding(.horizontal, 10).frame(height: 26)
            .frame(maxWidth: prominent ? nil : .infinity)
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(prominent ? Theme.accent : (hover ? Theme.raised : Theme.surface)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(prominent ? .clear : Theme.line))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
