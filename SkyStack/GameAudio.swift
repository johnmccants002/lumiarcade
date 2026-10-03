import AVFoundation

/// All synthesis and audio-session work happens away from rendering and touch handling.
final class GameAudio {
    enum Cue: Hashable { case placement, perfect(Int), alignment, pulseGate, pulseHigh, pulseCollision }
    private let queue = DispatchQueue(label: "lumiarcade.audio", qos: .utility)
    private var players: [Cue: AVAudioPlayer] = [:]
    private var prepared = false
    private var active = false

    func prepare() {
        queue.async { [self] in
            guard !prepared else { return }
            prepared = true
            do {
                // Ambient respects the silent switch and mixes with existing music.
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                let cues: [(Cue, Double, Double)] = [(.placement, 220, 0.045), (.alignment, 880, 0.07),
                                                     (.pulseGate, 660, 0.055), (.pulseHigh, 990, 0.13),
                                                     (.pulseCollision, 105, 0.16)]
                    + (1...5).map { (.perfect($0), 523.25 * pow(2, Double($0 - 1) / 12 * 2), 0.12) }
                for (cue, frequency, duration) in cues {
                    let player = try AVAudioPlayer(data: Self.tone(frequency: frequency, duration: duration))
                    player.volume = cue == .placement || cue == .pulseGate ? 0.16 : 0.22
                    players[cue] = player
                }
            } catch {
                players.removeAll() // Audio failure must never affect playability.
            }
        }
    }

    func play(_ cue: Cue) {
        queue.async { [self] in
            guard let player = players[cue] else { return }
            if !active {
                do { try AVAudioSession.sharedInstance().setActive(true); active = true }
                catch { return }
            }
            player.currentTime = 0
            player.play()
        }
    }

    func suspend() {
        queue.async { [self] in
            players.values.forEach { $0.stop() }
            if active { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
            active = false
        }
    }

    private static func tone(frequency: Double, duration: Double) -> Data {
        let rate = 22_050
        let samples = Int(Double(rate) * duration)
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func word<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        text("RIFF"); word(UInt32(36 + samples * 2)); text("WAVEfmt ")
        word(UInt32(16)); word(UInt16(1)); word(UInt16(1))
        word(UInt32(rate)); word(UInt32(rate * 2)); word(UInt16(2)); word(UInt16(16))
        text("data"); word(UInt32(samples * 2))
        for index in 0..<samples {
            let t = Double(index) / Double(rate)
            let envelope = min(1, t / 0.004) * pow(max(0, 1 - t / duration), 2)
            word(Int16(sin(2 * .pi * frequency * t) * envelope * 16_000))
        }
        return data
    }
}
