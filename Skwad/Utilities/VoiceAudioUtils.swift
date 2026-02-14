import Foundation

/// Pure audio processing functions extracted for testability
enum VoiceAudioUtils {

    /// Calculate RMS level from samples, scaled and clamped to 0...1
    static func calculateLevel(from samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        let rms = sqrtf(sumSquares / Float(samples.count))
        return min(1.0, max(0.0, rms * 5))
    }

    /// Interpolate between two sample arrays at a given progress (0...1)
    static func interpolate(previous: [Float], current: [Float], progress: Float) -> [Float] {
        let count = max(previous.count, current.count)
        var result = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let prev = i < previous.count ? previous[i] : 0
            let curr = i < current.count ? current[i] : 0
            result[i] = prev + (curr - prev) * progress
        }
        return result
    }

    /// Ease-out curve: 1 - (1 - t)^2
    static func easeOut(_ t: Float) -> Float {
        return 1 - (1 - t) * (1 - t)
    }

    /// Downsample audio buffer to waveform peak samples
    static func downsample(_ samples: [Float], to targetCount: Int) -> [Float] {
        guard !samples.isEmpty && targetCount > 0 else { return [] }

        var result = [Float](repeating: 0, count: targetCount)
        let samplesPerBin = samples.count / targetCount

        if samplesPerBin > 0 {
            for i in 0..<targetCount {
                let start = i * samplesPerBin
                let end = min(start + samplesPerBin, samples.count)

                var peak: Float = 0
                for j in start..<end {
                    peak = max(peak, abs(samples[j]))
                }
                result[i] = min(1.0, peak * 4)
            }
        }

        return result
    }

    /// Smooth audio level with exponential moving average (0.7 / 0.3 weights)
    static func smoothLevel(current: Float, new: Float) -> Float {
        current * 0.7 + new * 0.3
    }
}
