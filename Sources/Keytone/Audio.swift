import AVFoundation

let kSampleRate: Double = 48_000
let kFormat = AVAudioFormat(standardFormatWithSampleRate: kSampleRate, channels: 2)!

/// Low-latency polyphonic player tuned for fast typing:
/// - per-key choke: a new press of the same key fades out its previous sound
/// - ducking: older tails get quieter when a new sound starts, so attacks stay distinct
/// - polyphony cap: only the newest `maxActive` sounds keep playing
/// - peak limiter on the output so stacked sounds never clip
final class SoundEngine {
    private final class Voice {
        let player = AVAudioPlayerNode()
        let speed = AVAudioUnitVarispeed()
        var tag: Int = -1          // what triggered it (key code, mouse id) for choking
        var started: TimeInterval = 0
        var ends: TimeInterval = 0
        var baseVolume: Float = 0
        var generation = 0         // bumps on every reuse so stale fade-outs don't touch a new sound
        func isActive(_ now: TimeInterval) -> Bool { now < ends }
    }

    private let engine = AVAudioEngine()
    private let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
    private let bus = AVAudioMixerNode()
    private var voices: [Voice] = []
    private var next = 0

    private let maxActive = 8
    private let duck: Float = 0.6          // each newer sound multiplies older tails by this
    private let fade: TimeInterval = 0.012 // choke / steal fade-out

    init() {
        engine.attach(bus); engine.attach(limiter)
        for _ in 0..<24 {
            let v = Voice()
            engine.attach(v.player); engine.attach(v.speed)
            engine.connect(v.player, to: v.speed, format: kFormat)
            engine.connect(v.speed, to: bus, format: kFormat)
            voices.append(v)
        }
        engine.connect(bus, to: limiter, format: kFormat)
        engine.connect(limiter, to: engine.mainMixerNode, format: kFormat)
        engine.prepare()
        do { try engine.start(); Diag.log("audio engine started, out=\(engine.outputNode.outputFormat(forBus: 0))") } catch { Diag.log("audio engine FAILED: \(error)") }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            try? self?.engine.start()
        }
    }

    /// Short volume ramp then stop, avoiding the click of an abrupt cut.
    private func fadeOut(_ v: Voice) {
        let gen = v.generation, start = v.player.volume, steps = 4
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + fade * Double(i) / Double(steps)) {
                guard v.generation == gen else { return }
                if i == steps { v.player.stop(); v.ends = 0 } else { v.player.volume = start * Float(steps - i) / Float(steps) }
            }
        }
    }

    func play(_ buf: AVAudioPCMBuffer, volume: Float, pitch: Float = 1, pan: Float = 0, tag: Int = -1) {
        if !engine.isRunning { do { try engine.start() } catch { Diag.log("restart FAILED: \(error)") } }
        let now = ProcessInfo.processInfo.systemUptime

        var active = voices.filter { $0.isActive(now) }.sorted { $0.started < $1.started }
        // choke: same key retriggered
        if tag >= 0 {
            for v in active where v.tag == tag { fadeOut(v) }
            active.removeAll { $0.tag == tag }
        }
        // polyphony cap: fade the oldest
        while active.count >= maxActive { fadeOut(active.removeFirst()) }
        // duck the tails that keep ringing
        for v in active { v.player.volume *= duck }

        // pick a free voice (round-robin, skipping ones still ringing)
        var v = voices[next]
        for _ in 0..<voices.count where v.isActive(now) { next = (next + 1) % voices.count; v = voices[next] }
        next = (next + 1) % voices.count

        v.generation += 1
        v.player.stop()
        v.speed.rate = pitch
        v.baseVolume = volume
        v.player.volume = volume
        v.player.pan = pan
        v.tag = tag
        v.started = now
        v.ends = now + Double(buf.frameLength) / kSampleRate / Double(max(pitch, 0.5))
        v.player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        v.player.play()
    }
}

enum AudioIO {
    /// Loads any audio file into a 48 kHz stereo float buffer. Falls back to ffmpeg for formats CoreAudio can't read (e.g. .ogg).
    static func load(_ url: URL) -> AVAudioPCMBuffer? {
        if let b = readNative(url) { return b }
        guard let wav = transcodeWithFFmpeg(url) else { return nil }
        return readNative(wav)
    }

    private static func readNative(_ url: URL) -> AVAudioPCMBuffer? {
        guard let f = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)),
              (try? f.read(into: buf)) != nil else { return nil }
        return toStereo48k(buf)
    }

    private static func transcodeWithFFmpeg(_ url: URL) -> URL? {
        let candidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        guard let ff = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ff)
        p.arguments = ["-y", "-loglevel", "error", "-i", url.path, "-ar", "48000", "-ac", "2", out.path]
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        return p.terminationStatus == 0 ? out : nil
    }

    static func toStereo48k(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let ch = input.format.channelCount
        guard let mid = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: kSampleRate, channels: ch, interleaved: false) else { return nil }
        var resampled = input
        if input.format != mid {
            guard let conv = AVAudioConverter(from: input.format, to: mid) else { return nil }
            let cap = AVAudioFrameCount(Double(input.frameLength) * kSampleRate / input.format.sampleRate) + 4096
            guard let out = AVAudioPCMBuffer(pcmFormat: mid, frameCapacity: cap) else { return nil }
            var fed = false
            var err: NSError?
            conv.convert(to: out, error: &err) { _, status in
                if fed { status.pointee = .endOfStream; return nil }
                fed = true; status.pointee = .haveData; return input
            }
            if err != nil { return nil }
            resampled = out
        }
        guard let st = AVAudioPCMBuffer(pcmFormat: kFormat, frameCapacity: resampled.frameLength),
              let src = resampled.floatChannelData, let dst = st.floatChannelData else { return nil }
        let n = Int(resampled.frameLength)
        st.frameLength = resampled.frameLength
        for i in 0..<n {
            dst[0][i] = src[0][i]
            dst[1][i] = ch > 1 ? src[1][i] : src[0][i]
        }
        return st
    }

    static func slice(_ b: AVAudioPCMBuffer, startMs: Double, durMs: Double) -> AVAudioPCMBuffer? {
        var start = Int(startMs / 1000 * kSampleRate)
        let end = start + Int(durMs / 1000 * kSampleRate)
        // skip leading near-silence so the sound starts right on the keypress (keep 1 ms of lead-in)
        if let s = b.floatChannelData, start >= 0, end <= Int(b.frameLength) {
            var i = start
            while i < end, abs(s[0][i]) < 0.01, abs(s[1][i]) < 0.01 { i += 1 }
            if i < end { start = max(start, i - 48) }
        }
        let durMs = Double(end - start) / kSampleRate * 1000
        let len = min(Int(durMs / 1000 * kSampleRate), Int(b.frameLength) - start)
        guard start >= 0, len > 0, let out = AVAudioPCMBuffer(pcmFormat: kFormat, frameCapacity: AVAudioFrameCount(len)),
              let s = b.floatChannelData, let d = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(len)
        for c in 0..<2 { for i in 0..<len { d[c][i] = s[c][start + i] } }
        // short fade-out to avoid clicks at the cut
        let fade = min(240, len)
        for i in 0..<fade { let g = Float(i) / Float(fade); d[0][len-1-i] *= g; d[1][len-1-i] *= g }
        return out
    }
}
