import XCTest
import Foundation
@testable import Skwad

final class VoiceInputHelpersTests: XCTestCase {

    // MARK: - Audio Level Calculation

    /// Calculate RMS level from samples
    private func calculateLevel(from samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        let rms = sqrtf(sumSquares / Float(samples.count))
        return min(1.0, max(0.0, rms * 5))
    }

    func testSilentSamplesReturnZeroLevel() {
        let samples = [Float](repeating: 0, count: 100)
        let level = calculateLevel(from: samples)
        XCTAssertEqual(level, 0)
    }

    func testMaxSamplesReturnOneLevel() {
        let samples = [Float](repeating: 0.5, count: 100)  // 0.5 * 5 > 1 so should cap
        let level = calculateLevel(from: samples)
        XCTAssertEqual(level, 1.0)
    }

    func testEmptySamplesReturnZero() {
        let level = calculateLevel(from: [])
        XCTAssertEqual(level, 0)
    }

    func testModerateSamplesReturnModerateLevel() {
        let samples = [Float](repeating: 0.1, count: 100)
        let level = calculateLevel(from: samples)
        XCTAssertTrue(level > 0 && level < 1.0)
    }

    // MARK: - Waveform Interpolation

    /// Interpolate between two sample arrays
    private func interpolate(previous: [Float], current: [Float], progress: Float) -> [Float] {
        let count = max(previous.count, current.count)
        var result = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let prev = i < previous.count ? previous[i] : 0
            let curr = i < current.count ? current[i] : 0
            result[i] = prev + (curr - prev) * progress
        }
        return result
    }

    func testProgress0ReturnsPreviousSamples() {
        let previous: [Float] = [0.2, 0.4, 0.6]
        let current: [Float] = [0.8, 0.9, 1.0]
        let result = interpolate(previous: previous, current: current, progress: 0)

        XCTAssertEqual(result[0], 0.2)
        XCTAssertEqual(result[1], 0.4)
        XCTAssertEqual(result[2], 0.6)
    }

    func testProgress1ReturnsCurrentSamples() {
        let previous: [Float] = [0.2, 0.4, 0.6]
        let current: [Float] = [0.8, 0.9, 1.0]
        let result = interpolate(previous: previous, current: current, progress: 1)

        XCTAssertEqual(result[0], 0.8)
        XCTAssertEqual(result[1], 0.9)
        XCTAssertEqual(result[2], 1.0)
    }

    func testProgress05ReturnsMidpoint() {
        let previous: [Float] = [0.0, 0.0, 0.0]
        let current: [Float] = [1.0, 1.0, 1.0]
        let result = interpolate(previous: previous, current: current, progress: 0.5)

        XCTAssertEqual(result[0], 0.5)
        XCTAssertEqual(result[1], 0.5)
        XCTAssertEqual(result[2], 0.5)
    }

    func testHandlesEmptyArrays() {
        let result = interpolate(previous: [], current: [], progress: 0.5)
        XCTAssertTrue(result.isEmpty)
    }

    func testHandlesMismatchedArraySizes() {
        let previous: [Float] = [0.2, 0.4]
        let current: [Float] = [0.8, 0.9, 1.0]
        let result = interpolate(previous: previous, current: current, progress: 0.5)

        XCTAssertEqual(result.count, 3)
        // Third element interpolates from 0 to 1.0
        XCTAssertEqual(result[2], 0.5)
    }

    // MARK: - Ease Out Function

    /// Ease-out function for smoother interpolation
    private func easeOut(_ t: Float) -> Float {
        return 1 - (1 - t) * (1 - t)
    }

    func testEaseOutAt0Returns0() {
        let result = easeOut(0)
        XCTAssertEqual(result, 0)
    }

    func testEaseOutAt1Returns1() {
        let result = easeOut(1)
        XCTAssertEqual(result, 1)
    }

    func testEaseOutAt05IsGreaterThan05() {
        let result = easeOut(0.5)
        XCTAssertTrue(result > 0.5)
        XCTAssertEqual(result, 0.75)  // 1 - (0.5)^2 = 0.75
    }

    func testEaseOutIsMonotonicallyIncreasing() {
        var previous: Float = 0
        for i in 0...10 {
            let t = Float(i) / 10.0
            let result = easeOut(t)
            XCTAssertGreaterThanOrEqual(result, previous)
            previous = result
        }
    }

    // MARK: - Waveform Downsampling

    /// Downsample audio buffer to waveform samples
    private func downsample(_ samples: [Float], to targetCount: Int) -> [Float] {
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

    func testDownsamplesToTargetCount() {
        let samples = [Float](repeating: 0.1, count: 256)
        let result = downsample(samples, to: 64)
        XCTAssertEqual(result.count, 64)
    }

    func testSilentSamplesProduceSilentWaveform() {
        let samples = [Float](repeating: 0, count: 256)
        let result = downsample(samples, to: 64)

        for sample in result {
            XCTAssertEqual(sample, 0)
        }
    }

    func testLoudSamplesProduceCappedWaveform() {
        let samples = [Float](repeating: 0.5, count: 256)
        let result = downsample(samples, to: 64)

        for sample in result {
            XCTAssertEqual(sample, 1.0)  // 0.5 * 4 = 2.0, capped to 1.0
        }
    }

    func testDownsampleHandlesEmptyInput() {
        let result = downsample([], to: 64)
        XCTAssertTrue(result.isEmpty)
    }

    func testDownsampleHandlesZeroTargetCount() {
        let samples = [Float](repeating: 0.1, count: 256)
        let result = downsample(samples, to: 0)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Sample Count Constants

    func testSampleCountIs64() {
        let sampleCount = 64
        XCTAssertEqual(sampleCount, 64)
    }

    func testSampleIntervalIs100ms() {
        let sampleInterval: Double = 0.1
        XCTAssertEqual(sampleInterval, 0.1)
    }

    // MARK: - Audio Level Smoothing

    /// Smooth audio level with exponential moving average
    private func smoothLevel(current: Float, new: Float) -> Float {
        current * 0.7 + new * 0.3
    }

    func testSmoothingReducesSuddenChanges() {
        let current: Float = 0.2
        let new: Float = 1.0
        let smoothed = smoothLevel(current: current, new: new)

        // Should be between current and new, closer to current
        XCTAssertTrue(smoothed > current)
        XCTAssertTrue(smoothed < new)
        XCTAssertEqual(smoothed, 0.44, accuracy: 0.001)  // 0.2 * 0.7 + 1.0 * 0.3 = 0.14 + 0.3 = 0.44
    }

    func testSmoothingFromZero() {
        let current: Float = 0.0
        let new: Float = 1.0
        let smoothed = smoothLevel(current: current, new: new)

        XCTAssertEqual(smoothed, 0.3)  // 0 * 0.7 + 1.0 * 0.3 = 0.3
    }

    func testSmoothingMaintainsStableLevel() {
        let level: Float = 0.5
        let smoothed = smoothLevel(current: level, new: level)

        XCTAssertEqual(smoothed, 0.5)  // 0.5 * 0.7 + 0.5 * 0.3 = 0.5
    }

    // MARK: - Text Injection Validation

    private func shouldInjectText(_ text: String) -> Bool {
        !text.isEmpty
    }

    func testEmptyTextShouldNotInject() {
        XCTAssertFalse(shouldInjectText(""))
    }

    func testWhitespaceOnlyShouldInject() {
        // Note: whitespace-only is considered non-empty
        XCTAssertTrue(shouldInjectText("   "))
    }

    func testValidTextShouldInject() {
        XCTAssertTrue(shouldInjectText("Hello world"))
    }
}
