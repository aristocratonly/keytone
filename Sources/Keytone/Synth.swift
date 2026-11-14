import AVFoundation

/// One resonance of the keyboard (case, plate, keycap, spring...).
struct Mode {
    var f: Double   // Hz
    var q: Double   // higher = rings longer
    var g: Double   // relative gain
}

/// Modal model of a keystroke: a short, soft impact excites a bank of resonances,
/// plus optional switch click / tactile tick, then gentle low-pass and a tiny "room".
struct ClickSpec {
    var modes: [Mode]
    var exciteMs: Double = 1.5        // impact softness: longer = rounder, less sharp
    var cutoff: Double = 5000         // final low-pass, Hz
    var noise: Double = 0.15          // contact/friction noise
    var noiseDecay: Double = 0.006
    var click: Double = 0             // click-jacket / buckling-spring click
    var clickFreq: Double = 4000
    var clickOnRelease = false
    var tick: Double = 0              // tactile bump before bottom-out
    var bottomDelay: Double = 0.006
    var length: Double = 0.12
    var room: Double = 0.12
    var level: Double = 0.45          // output peak (kept well below 1 to avoid harshness)
}

private struct Biquad {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    /// Band-pass, constant 0 dB peak gain (RBJ cookbook).
    static func bandpass(_ f: Double, _ q: Double) -> Biquad {
        let w = 2 * .pi * min(f, kSampleRate * 0.45) / kSampleRate
        let alpha = sin(w) / (2 * q), a0 = 1 + alpha
        var b = Biquad()
        b.b0 = alpha / a0; b.b1 = 0; b.b2 = -alpha / a0
        b.a1 = -2 * cos(w) / a0; b.a2 = (1 - alpha) / a0
        return b
    }
    static func lowpass(_ f: Double, _ q: Double = 0.707) -> Biquad {
        let w = 2 * .pi * min(f, kSampleRate * 0.45) / kSampleRate
        let alpha = sin(w) / (2 * q), a0 = 1 + alpha, c = cos(w)
        var b = Biquad()
        b.b0 = (1 - c) / 2 / a0; b.b1 = (1 - c) / a0; b.b2 = (1 - c) / 2 / a0
        b.a1 = -2 * c / a0; b.a2 = (1 - alpha) / a0
        return b
    }
    static func highpass(_ f: Double) -> Biquad {
        let w = 2 * .pi * f / kSampleRate
        let alpha = sin(w) / (2 * 0.707), a0 = 1 + alpha, c = cos(w)
        var b = Biquad()
        b.b0 = (1 + c) / 2 / a0; b.b1 = -(1 + c) / a0; b.b2 = (1 + c) / 2 / a0
        b.a1 = -2 * c / a0; b.a2 = (1 - alpha) / a0
        return b
    }
    mutating func run(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }
}

enum Synth {
    static func render(_ s: ClickSpec, freqScale: Double = 1, decayScale: Double = 1,
                       gain: Double = 1, release: Bool = false) -> AVAudioPCMBuffer {
        var rng = SystemRandomNumberGenerator()
        func rnd() -> Double { Double.random(in: -1...1, using: &rng) }
        func jit(_ a: Double) -> Double { 1 + Double.random(in: -a...a, using: &rng) }

        let n = Int(s.length * decayScale * kSampleRate)
        let sr = kSampleRate
        var excite = [Double](repeating: 0, count: n)   // goes into the resonators
        var direct = [Double](repeating: 0, count: n)   // added after (noise, click)

        func impulse(at t0: Double, ms: Double, amp: Double) {
            let start = Int(t0 * sr), len = max(2, Int(ms / 1000 * sr))
            for i in 0..<len where start + i < n {
                let w = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(len - 1))   // Hann: soft attack
                excite[start + i] += (0.6 * rnd() + 0.4) * w * amp
            }
        }

        let pitch = freqScale * (release ? 1.12 : 1) * jit(0.03)
        let impactAt = release ? 0.0 : s.bottomDelay * jit(0.15)
        let impactAmp = (release ? 0.38 : 1) * jit(0.08)

        // tactile bump: tiny, earlier excitation
        if s.tick > 0 && !release { impulse(at: 0, ms: 0.8, amp: s.tick) }
        // bottom-out (or upstroke on release)
        impulse(at: impactAt, ms: s.exciteMs * (release ? 0.8 : 1) * jit(0.15), amp: impactAmp)

        // contact noise
        if s.noise > 0 {
            let start = Int(impactAt * sr)
            for i in start..<n {
                let t = Double(i - start) / sr
                direct[i] += rnd() * exp(-t / (s.noiseDecay * decayScale)) * s.noise * impactAmp
            }
        }
        // click
        if s.click > 0 && (!release || s.clickOnRelease) {
            let amp = s.click * (release ? 0.6 : 1) * jit(0.1)
            var bp = Biquad.bandpass(s.clickFreq * jit(0.04), 3)
            for i in 0..<min(n, Int(0.006 * sr)) {
                let t = Double(i) / sr
                direct[i] += bp.run(rnd()) * exp(-t / 0.0008) * amp * 3
            }
        }

        // resonator bank
        var out = [Double](repeating: 0, count: n)
        for m in s.modes {
            var bp = Biquad.bandpass(m.f * pitch * jit(0.02), m.q * decayScale)
            let g = m.g * jit(0.1)
            for i in 0..<n { out[i] += bp.run(excite[i]) * g }
        }
        for i in 0..<n { out[i] += direct[i] }

        // tone shaping: remove rumble, soften highs
        var hp = Biquad.highpass(70)
        var lp1 = Biquad.lowpass(s.cutoff), lp2 = Biquad.lowpass(s.cutoff * 1.3)
        for i in 0..<n { out[i] = lp2.run(lp1.run(hp.run(out[i]))) }

        // tiny room: a few early reflections from the desk/case
        if s.room > 0 {
            let taps: [(Double, Double)] = [(0.0047, 0.5), (0.0091, 0.32), (0.0153, 0.2), (0.0237, 0.12)]
            let dry = out
            for (d, g) in taps {
                let off = Int(d * sr)
                for i in off..<n { out[i] += dry[i - off] * g * s.room }
            }
        }

        // fades and level
        let fo = min(Int(0.012 * sr), n)
        for i in 0..<fo { out[n - 1 - i] *= Double(i) / Double(fo) }
        let peak = out.reduce(0) { max($0, abs($1)) }
        let norm = peak > 0 ? s.level * gain * (release ? 0.5 : 1) / peak : 0

        let buf = AVAudioPCMBuffer(pcmFormat: kFormat, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let d = buf.floatChannelData!
        for i in 0..<n { let v = Float(out[i] * norm); d[0][i] = v; d[1][i] = v }
        return buf
    }
}
