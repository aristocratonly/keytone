import SwiftUI
import ServiceManagement

@MainActor @Observable
final class AppState {
    static let shared = AppState()

    @ObservationIgnored let engine = SoundEngine()
    @ObservationIgnored let monitor = InputMonitor()
    @ObservationIgnored private let d = UserDefaults.standard

    var customPacks: [KeyPack] = []
    var keyPacks: [KeyPack] { Library.builtInKeys + customPacks }

    var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    var keyProfile: String { didSet { d.set(keyProfile, forKey: "keyProfile") } }
    var mouseProfile: String { didSet { d.set(mouseProfile, forKey: "mouseProfile") } }
    var mouseEnabled: Bool { didSet { d.set(mouseEnabled, forKey: "mouseEnabled") } }
    var keyVolume: Double { didSet { d.set(keyVolume, forKey: "keyVolume") } }
    var mouseVolume: Double { didSet { d.set(mouseVolume, forKey: "mouseVolume") } }
    var pitchVariance: Double { didSet { d.set(pitchVariance, forKey: "pitchVariance") } }
    var playRelease: Bool { didSet { d.set(playRelease, forKey: "playRelease") } }
    var ignoreRepeat: Bool { didSet { d.set(ignoreRepeat, forKey: "ignoreRepeat") } }
    var stereo: Bool { didSet { d.set(stereo, forKey: "stereo") } }
    var scrollEnabled: Bool { didSet { d.set(scrollEnabled, forKey: "scrollEnabled") } }

    var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            guard !syncingLogin else { return }
            do { launchAtLogin ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
            catch { importMessage = "Автозапуск: \(error.localizedDescription)" }
            // reflect the real state (a failed or pending registration must not leave the box ticked)
            let actual = SMAppService.mainApp.status == .enabled
            if actual != launchAtLogin { syncingLogin = true; launchAtLogin = actual; syncingLogin = false }
            if SMAppService.mainApp.status == .requiresApproval {
                importMessage = "Подтвердите автозапуск в Настройках → Основные → Объекты входа"
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
    @ObservationIgnored private var syncingLogin = false

    var hasPermission = InputMonitor.hasKeyboardAccess
    var importMessage: String?

    private init() {
        d.register(defaults: ["enabled": true, "keyProfile": "mv:Creamy Legendary", "mouseProfile": "soft", "mouseEnabled": true,
                              "keyVolume": 0.75, "mouseVolume": 0.6, "pitchVariance": 0.45, "playRelease": true,
                              "ignoreRepeat": true, "stereo": true, "scrollEnabled": true])
        enabled = d.bool(forKey: "enabled")
        keyProfile = d.string(forKey: "keyProfile") ?? "mv:Creamy Legendary"
        mouseProfile = d.string(forKey: "mouseProfile") ?? "soft"
        mouseEnabled = d.bool(forKey: "mouseEnabled")
        keyVolume = d.double(forKey: "keyVolume")
        mouseVolume = d.double(forKey: "mouseVolume")
        pitchVariance = d.double(forKey: "pitchVariance")
        playRelease = d.bool(forKey: "playRelease")
        ignoreRepeat = d.bool(forKey: "ignoreRepeat")
        stereo = d.bool(forKey: "stereo")
        scrollEnabled = d.bool(forKey: "scrollEnabled")

        customPacks = Library.loadCustom()
        if !keyPacks.contains(where: { $0.id == keyProfile }) { keyProfile = keyPacks.first?.id ?? "" }
        monitor.handler = { [weak self] e in MainActor.assumeIsolated { self?.handle(e) } }
        monitor.start()
        if !InputMonitor.hasKeyboardAccess { InputMonitor.requestKeyboardAccess() }   // system prompt + adds Keytone to the list
        watchPermission()
    }

    var currentKeyPack: KeyPack? { keyPacks.first { $0.id == keyProfile } ?? keyPacks.first }
    var currentMousePack: MousePack? { Library.mouse.first { $0.id == mouseProfile } ?? Library.mouse.first }

    private func watchPermission() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let ok = InputMonitor.hasKeyboardAccess
                if ok != self.hasPermission {
                    self.hasPermission = ok
                    self.monitor.stop(); self.monitor.start()   // re-create the tap so key events start flowing
                }
            }
        }
    }

    func requestPermission() {
        InputMonitor.requestKeyboardAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    private func pitch() -> Float { Float(1 + Double.random(in: -1...1) * 0.06 * pitchVariance) }
    /// Key sounds play slightly faster than recorded: shorter, snappier, a hair brighter.
    private let keySpeed: Float = 1.05

    func handle(_ e: InputEvent) {
        switch e {
        case let .key(code, down, isRepeat):
            guard enabled else { return }
            if down && isRepeat && ignoreRepeat { return }
            if !down && !playRelease { return }
            guard let buf = currentKeyPack?.buffer(key: code, down: down) else { return }
            let pan = stereo ? Float(((Keymap.column[code] ?? 0.5) - 0.5) * 0.7) : 0
            engine.play(buf, volume: Float(keyVolume) * (down ? 1 : 0.7), pitch: pitch() * keySpeed, pan: pan, tag: Int(code) + (down ? 0 : 500))
        case let .mouse(button, down):
            guard enabled, mouseEnabled, let buf = currentMousePack?.buffer(button: button, down: down) else { return }
            engine.play(buf, volume: Float(mouseVolume) * (down ? 1 : 0.75), pitch: pitch(), tag: 1000 + button)
        case .scroll:
            guard enabled, mouseEnabled, scrollEnabled, let buf = currentMousePack?.scroll() else { return }
            engine.play(buf, volume: Float(mouseVolume) * 0.6, pitch: pitch(), tag: 1100)
        }
    }

    /// Plays a short typing demo for a profile.
    func preview(_ pack: KeyPack) {
        let seq: [UInt16] = [4, 14, 37, 37, 31, 49]
        for (i, k) in seq.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { [weak self] in
                guard let self, let b = pack.buffer(key: k, down: true) else { return }
                self.engine.play(b, volume: Float(self.keyVolume), pitch: self.pitch() * self.keySpeed)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    if self.playRelease, let u = pack.buffer(key: k, down: false) { self.engine.play(u, volume: Float(self.keyVolume) * 0.7, pitch: self.pitch() * self.keySpeed) }
                }
            }
        }
    }

    func preview(_ pack: MousePack) {
        for i in 0..<2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) { [weak self] in
                guard let self else { return }
                if let b = pack.buffer(button: 0, down: true) { self.engine.play(b, volume: Float(self.mouseVolume)) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    if let b = pack.buffer(button: 0, down: false) { self.engine.play(b, volume: Float(self.mouseVolume) * 0.75) }
                }
            }
        }
    }

    func importPack() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip, .folder]
        panel.message = "Выберите папку или .zip с паком Mechvibes"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let err = Library.importPack(from: url) { importMessage = err; return }
        customPacks = Library.loadCustom()
        importMessage = "Пак импортирован"
        if let last = customPacks.first(where: { $0.folder?.lastPathComponent == url.deletingPathExtension().lastPathComponent }) ?? customPacks.last {
            keyProfile = last.id
        }
    }

    func remove(_ pack: KeyPack) {
        if let f = pack.folder { try? FileManager.default.trashItem(at: f, resultingItemURL: nil) }
        customPacks = Library.loadCustom()
        if keyProfile == pack.id { keyProfile = keyPacks.first?.id ?? "" }
    }
}
