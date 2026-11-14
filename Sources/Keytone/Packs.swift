import AVFoundation
import AppKit

// MARK: - Keyboard packs

class KeyPack: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let tags: [String]
    let isCustom: Bool
    var folder: URL?

    init(id: String, name: String, subtitle: String, symbol: String, tags: [String], isCustom: Bool) {
        self.id = id; self.name = name; self.subtitle = subtitle; self.symbol = symbol; self.tags = tags; self.isCustom = isCustom
    }
    func buffer(key: UInt16, down: Bool) -> AVAudioPCMBuffer? { nil }
}

final class SynthKeyPack: KeyPack {
    private var down: [KeyCategory: [AVAudioPCMBuffer]] = [:]
    private var up: [KeyCategory: [AVAudioPCMBuffer]] = [:]
    private let spec: ClickSpec
    private var built = false

    init(id: String, name: String, subtitle: String, symbol: String, tags: [String], spec: ClickSpec) {
        self.spec = spec
        super.init(id: id, name: name, subtitle: subtitle, symbol: symbol, tags: tags, isCustom: false)
    }

    private func build() {
        guard !built else { return }
        built = true
        for cat in KeyCategory.allCases {
            let (f, d, g): (Double, Double, Double) = switch cat {
                case .normal: (1, 1, 1)
                case .space: (0.68, 1.6, 1.15)
                case .enter: (0.82, 1.3, 1.08)
                case .backspace: (0.88, 1.2, 1.04)
                case .modifier: (0.94, 1.05, 0.88)
            }
            down[cat] = (0..<6).map { _ in Synth.render(spec, freqScale: f, decayScale: d, gain: g) }
            up[cat] = (0..<4).map { _ in Synth.render(spec, freqScale: f, decayScale: d, gain: g, release: true) }
        }
    }

    override func buffer(key: UInt16, down isDown: Bool) -> AVAudioPCMBuffer? {
        build()
        let cat = Keymap.category(key)
        return (isDown ? down[cat] : up[cat])?.randomElement()
    }
}

/// Mechvibes-compatible pack: a folder with config.json + audio (single sprite file or one file per key).
final class MechvibesPack: KeyPack {
    private var downs: [String: AVAudioPCMBuffer] = [:]   // key: scancode string (v1) or KeyboardEvent.code (v2)
    private var ups: [String: AVAudioPCMBuffer] = [:]
    private var pool: [AVAudioPCMBuffer] = []
    private var upPool: [AVAudioPCMBuffer] = []
    private var v2 = false
    private(set) var gain: Float = 1

    init?(folder: URL, custom: Bool = true) {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("config.json")),
              let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let name = (cfg["name"] as? String) ?? folder.lastPathComponent
        let author = (cfg["author"] as? String).map { "by " + $0 } ?? "Mechvibes"
        super.init(id: (custom ? "user:" : "mv:") + folder.lastPathComponent, name: name, subtitle: author,
                   symbol: custom ? "waveform" : "keyboard", tags: [], isCustom: custom)
        self.folder = folder

        if let defs = cfg["definitions"] as? [String: Any] {
            // ---- v2: {"KeyA": {"timing": [[startMs, endMs], [upStart, upEnd]]}} or per-key files
            v2 = true
            if let opts = cfg["options"] as? [String: Any], let rv = opts["recommended_volume"] as? NSNumber {
                gain = min(1.5, max(0.1, rv.floatValue))
            }
            let method = (cfg["definition_method"] as? String) ?? "single"
            var sprite: AVAudioPCMBuffer?
            if method == "single" {
                guard let file = cfg["audio_file"] as? String, let b = AudioIO.load(folder.appendingPathComponent(file)) else { return nil }
                sprite = b
            }
            for (k, v) in defs {
                guard let d = v as? [String: Any] else { continue }
                if let sprite, let timing = d["timing"] as? [[NSNumber]] {
                    for (idx, seg) in timing.prefix(2).enumerated() where seg.count >= 2 {
                        let a = seg[0].doubleValue, b = seg[1].doubleValue
                        guard let buf = AudioIO.slice(sprite, startMs: a, durMs: b - a) else { continue }
                        if idx == 0 { downs[k] = buf; pool.append(buf) } else { ups[k] = buf; upPool.append(buf) }
                    }
                } else if let files = d["audio_file"] as? [String] ?? (d["audio_file"] as? String).map({ [$0] }) {
                    for (idx, f) in files.prefix(2).enumerated() {
                        guard let buf = AudioIO.load(folder.appendingPathComponent(f)) else { continue }
                        if idx == 0 { downs[k] = buf; pool.append(buf) } else { ups[k] = buf; upPool.append(buf) }
                    }
                }
            }
        } else if let defines = cfg["defines"] as? [String: Any] {
            // ---- v1: {"30": [startMs, durMs]} (single) or {"30": "file.wav"} (multi), keys are scancodes
            let type = (cfg["key_define_type"] as? String) ?? "single"
            var sprite: AVAudioPCMBuffer?
            if type == "single", let file = cfg["sound"] as? String {
                guard let b = AudioIO.load(folder.appendingPathComponent(file)) else { return nil }
                sprite = b
            }
            for (k, v) in defines {
                let isUp = k.hasSuffix("-up")
                let key = isUp ? String(k.dropLast(3)) : k
                var buf: AVAudioPCMBuffer?
                if let sprite, let arr = v as? [NSNumber], arr.count >= 2 {
                    buf = AudioIO.slice(sprite, startMs: arr[0].doubleValue, durMs: arr[1].doubleValue)
                } else if let file = v as? String {
                    buf = AudioIO.load(folder.appendingPathComponent(file))
                }
                guard let buf else { continue }
                if isUp { ups[key] = buf; upPool.append(buf) } else { downs[key] = buf; pool.append(buf) }
            }
        } else { return nil }
        if pool.isEmpty { return nil }
        // loudness match: bring the typical key peak to ~0.5 so packs sit at the same level as each other
        let peaks = pool.prefix(40).map { b -> Float in
            let d = b.floatChannelData![0]; var m: Float = 0
            for i in 0..<Int(b.frameLength) { m = max(m, abs(d[i])) }
            return m
        }.sorted()
        let median = peaks[peaks.count / 2]
        if median > 0.001 { gain *= min(3, 0.5 / median) }
        // AVAudioPlayerNode.volume is capped at 1.0, so apply the gain to the samples themselves.
        var seen = Set<ObjectIdentifier>()
        for b in pool + upPool where seen.insert(ObjectIdentifier(b)).inserted {
            let n = Int(b.frameLength)
            for c in 0..<Int(b.format.channelCount) {
                let d = b.floatChannelData![c]
                for i in 0..<n { d[i] = max(-0.98, min(0.98, d[i] * gain)) }
            }
        }
        gain = 1
    }

    var keyCount: Int { downs.count }
    var hasRelease: Bool { !ups.isEmpty }

    override func buffer(key: UInt16, down: Bool) -> AVAudioPCMBuffer? {
        let k = v2 ? (Keymap.codeName[key] ?? "") : String(Keymap.scancode[key] ?? -1)
        if down { return downs[k] ?? pool.randomElement() }
        return ups[k] ?? (v2 ? upPool.randomElement() : nil)
    }
}

// MARK: - Mouse packs

final class MousePack: Identifiable {
    let id: String, name: String, subtitle: String, symbol: String
    private let spec: ClickSpec
    private lazy var leftDown = (0..<5).map { _ in Synth.render(spec) }
    private lazy var leftUp = (0..<4).map { _ in Synth.render(spec, release: true) }
    private lazy var rightDown = (0..<5).map { _ in Synth.render(spec, freqScale: 0.93) }
    private lazy var rightUp = (0..<4).map { _ in Synth.render(spec, freqScale: 0.93, release: true) }
    private lazy var wheel: [AVAudioPCMBuffer] = {
        var s = spec; s.click = 0; s.tick = 0; s.length = 0.035; s.noise = 0.05; s.bottomDelay = 0; s.exciteMs = 0.6; s.room = 0
        return (0..<4).map { _ in Synth.render(s, freqScale: 1.5, gain: 0.4) }
    }()

    init(id: String, name: String, subtitle: String, symbol: String, spec: ClickSpec) {
        self.id = id; self.name = name; self.subtitle = subtitle; self.symbol = symbol; self.spec = spec
    }

    func buffer(button: Int, down: Bool) -> AVAudioPCMBuffer? {
        (button == 1 ? (down ? rightDown : rightUp) : (down ? leftDown : leftUp)).randomElement()
    }
    func scroll() -> AVAudioPCMBuffer? { wheel.randomElement() }
}

// MARK: - Library

enum Library {
    /// Packs shipped inside the app bundle (Contents/Resources/Packs).
    static let builtInKeys: [KeyPack] = {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Packs"),
              let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        let order = ["Creamy Legendary", "(the creamiest one) Zoom TKL morandi switches Lubed", "amazin keychron q3 bluex", "wooting 60he"]
        return items.sorted { (order.firstIndex(of: $0.lastPathComponent) ?? 99, $0.lastPathComponent) < (order.firstIndex(of: $1.lastPathComponent) ?? 99, $1.lastPathComponent) }
            .compactMap { MechvibesPack(folder: $0, custom: false) }
    }()

    static let mouse: [MousePack] = [
        MousePack(id: "soft", name: "Silent", subtitle: "Тихий клик", symbol: "moon",
            spec: ClickSpec(modes: [Mode(f: 520, q: 4, g: 1), Mode(f: 1300, q: 4, g: 0.3)],
                            exciteMs: 2.2, cutoff: 2600, noise: 0.03, bottomDelay: 0, length: 0.05, room: 0.05, level: 0.4)),
        MousePack(id: "gaming", name: "Gaming", subtitle: "Чёткий", symbol: "scope",
            spec: ClickSpec(modes: [Mode(f: 1250, q: 8, g: 0.7), Mode(f: 2900, q: 10, g: 0.4)],
                            exciteMs: 0.7, cutoff: 7000, noise: 0.03, click: 0.6, clickFreq: 4800, clickOnRelease: true,
                            bottomDelay: 0.002, length: 0.05, room: 0.05, level: 0.42)),
        MousePack(id: "retro", name: "Retro", subtitle: "Старая шариковая", symbol: "circle.circle",
            spec: ClickSpec(modes: [Mode(f: 800, q: 9, g: 0.7), Mode(f: 1900, q: 12, g: 0.4)],
                            exciteMs: 1.1, cutoff: 5000, noise: 0.06, click: 0.5, clickFreq: 2900, clickOnRelease: true,
                            bottomDelay: 0.003, length: 0.07, room: 0.08, level: 0.45)),
    ]
    static var packsDir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Keytone/Packs", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func loadCustom() -> [KeyPack] {
        let items = (try? FileManager.default.contentsOfDirectory(at: packsDir, includingPropertiesForKeys: nil)) ?? []
        return items.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { MechvibesPack(folder: $0) }
    }

    /// Imports a Mechvibes pack from a folder or .zip. Returns an error message on failure.
    static func importPack(from url: URL) -> String? {
        let fm = FileManager.default
        var root = url
        if url.pathExtension.lowercased() == "zip" {
            let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            p.arguments = ["-x", "-k", url.path, tmp.path]
            do { try p.run(); p.waitUntilExit() } catch { return "Не удалось распаковать архив" }
            root = tmp
        }
        guard let cfg = findConfig(in: root) else { return "В папке не найден config.json" }
        let src = cfg.deletingLastPathComponent()
        let unzippedFlat = root != url && src.standardizedFileURL == root.standardizedFileURL
        let dst = packsDir.appendingPathComponent(unzippedFlat ? url.deletingPathExtension().lastPathComponent : src.lastPathComponent)
        try? fm.removeItem(at: dst)
        do { try fm.copyItem(at: src, to: dst) } catch { return "Не удалось скопировать пак" }
        return MechvibesPack(folder: dst) == nil ? "Пак не распознан (неподдерживаемый формат звука?)" : nil
    }

    private static func findConfig(in dir: URL) -> URL? {
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
        while let u = e?.nextObject() as? URL {
            if u.lastPathComponent == "config.json", !u.path.contains("__MACOSX") { return u }
        }
        return nil
    }
}
