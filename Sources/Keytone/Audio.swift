import AVFoundation

let kSampleRate: Double = 48_000
let kFormat = AVAudioFormat(standardFormatWithSampleRate: kSampleRate, channels: 2)!

/// Low-latency polyphonic player: a ring of player nodes so fast typing overlaps instead of cutting off.
final class SoundEngine {
    private let engine = AVAudioEngine()
    private var voices: [(AVAudioPlayerNode, AVAudioUnitVarispeed)] = []
    private var next = 0

    init() {
        for _ in 0..<24 {
            let p = AVAudioPlayerNode(), v = AVAudioUnitVarispeed()
            engine.attach(p); engine.attach(v)
            engine.connect(p, to: v, format: kFormat)
            engine.connect(v, to: engine.mainMixerNode, format: kFormat)
            voices.append((p, v))
        }
        engine.prepare()
        do { try engine.start(); Diag.log("audio engine started, out=\(engine.outputNode.outputFormat(forBus: 0))") } catch { Diag.log("audio engine FAILED: \(error)") }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            try? self?.engine.start()
        }
    }

    func play(_ buf: AVAudioPCMBuffer, volume: Float, pitch: Float = 1, pan: Float = 0) {
        if !engine.isRunning { do { try engine.start() } catch { Diag.log("restart FAILED: \(error)") } }
        let (p, v) = voices[next]
        next = (next + 1) % voices.count
        p.stop()
        v.rate = pitch
        p.volume = volume
        p.pan = pan
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        p.play()
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
        let start = Int(startMs / 1000 * kSampleRate)
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
