import XCTest
import Foundation
@testable import Skwad

final class VoiceInputHelpersTests: XCTestCase {

    // MARK: - Audio Level Calculation

    func testSilentSamplesReturnZeroLevel() {
        let samples = [Float](repeating: 0, count: 100)
        let level = VoiceAudioUtils.calculateLevel(from: samples)
        XCTAssertEqual(level, 0)
    }

    func testMaxSamplesReturnOneLevel() {
        let samples = [Float](repeating: 0.5, count: 100)  // 0.5 * 5 > 1 so should cap
        let level = VoiceAudioUtils.calculateLevel(from: samples)
        XCTAssertEqual(level, 1.0)
    }

    func testEmptySamplesReturnZero() {
        let level = VoiceAudioUtils.calculateLevel(from: [])
        XCTAssertEqual(level, 0)
    }

    func testModerateSamplesReturnModerateLevel() {
        let samples = [Float](repeating: 0.1, count: 100)
        let level = VoiceAudioUtils.calculateLevel(from: samples)
        XCTAssertTrue(level > 0 && level < 1.0)
    }

    // MARK: - Waveform Interpolation

    func testProgress0ReturnsPreviousSamples() {
        let previous: [Float] = [0.2, 0.4, 0.6]
        let current: [Float] = [0.8, 0.9, 1.0]
        let result = VoiceAudioUtils.interpolate(previous: previous, current: current, progress: 0)

        XCTAssertEqual(result[0], 0.2)
        XCTAssertEqual(result[1], 0.4)
        XCTAssertEqual(result[2], 0.6)
    }

    func testProgress1ReturnsCurrentSamples() {
        let previous: [Float] = [0.2, 0.4, 0.6]
        let current: [Float] = [0.8, 0.9, 1.0]
        let result = VoiceAudioUtils.interpolate(previous: previous, current: current, progress: 1)

        XCTAssertEqual(result[0], 0.8)
        XCTAssertEqual(result[1], 0.9)
        XCTAssertEqual(result[2], 1.0)
    }

    func testProgress05ReturnsMidpoint() {
        let previous: [Float] = [0.0, 0.0, 0.0]
        let current: [Float] = [1.0, 1.0, 1.0]
        let result = VoiceAudioUtils.interpolate(previous: previous, current: current, progress: 0.5)

        XCTAssertEqual(result[0], 0.5)
        XCTAssertEqual(result[1], 0.5)
        XCTAssertEqual(result[2], 0.5)
    }

    func testHandlesEmptyArrays() {
        let result = VoiceAudioUtils.interpolate(previous: [], current: [], progress: 0.5)
        XCTAssertTrue(result.isEmpty)
    }

    func testHandlesMismatchedArraySizes() {
        let previous: [Float] = [0.2, 0.4]
        let current: [Float] = [0.8, 0.9, 1.0]
        let result = VoiceAudioUtils.interpolate(previous: previous, current: current, progress: 0.5)

        XCTAssertEqual(result.count, 3)
        // Third element interpolates from 0 to 1.0
        XCTAssertEqual(result[2], 0.5)
    }

    // MARK: - Ease Out Function

    func testEaseOutAt0Returns0() {
        XCTAssertEqual(VoiceAudioUtils.easeOut(0), 0)
    }

    func testEaseOutAt1Returns1() {
        XCTAssertEqual(VoiceAudioUtils.easeOut(1), 1)
    }

    func testEaseOutAt05IsGreaterThan05() {
        let result = VoiceAudioUtils.easeOut(0.5)
        XCTAssertTrue(result > 0.5)
        XCTAssertEqual(result, 0.75)  // 1 - (0.5)^2 = 0.75
    }

    func testEaseOutIsMonotonicallyIncreasing() {
        var previous: Float = 0
        for i in 0...10 {
            let t = Float(i) / 10.0
            let result = VoiceAudioUtils.easeOut(t)
            XCTAssertGreaterThanOrEqual(result, previous)
            previous = result
        }
    }

    // MARK: - Waveform Downsampling

    func testDownsamplesToTargetCount() {
        let samples = [Float](repeating: 0.1, count: 256)
        let result = VoiceAudioUtils.downsample(samples, to: 64)
        XCTAssertEqual(result.count, 64)
    }

    func testSilentSamplesProduceSilentWaveform() {
        let samples = [Float](repeating: 0, count: 256)
        let result = VoiceAudioUtils.downsample(samples, to: 64)

        for sample in result {
            XCTAssertEqual(sample, 0)
        }
    }

    func testLoudSamplesProduceCappedWaveform() {
        let samples = [Float](repeating: 0.5, count: 256)
        let result = VoiceAudioUtils.downsample(samples, to: 64)

        for sample in result {
            XCTAssertEqual(sample, 1.0)  // 0.5 * 4 = 2.0, capped to 1.0
        }
    }

    func testDownsampleHandlesEmptyInput() {
        let result = VoiceAudioUtils.downsample([], to: 64)
        XCTAssertTrue(result.isEmpty)
    }

    func testDownsampleHandlesZeroTargetCount() {
        let samples = [Float](repeating: 0.1, count: 256)
        let result = VoiceAudioUtils.downsample(samples, to: 0)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Audio Level Smoothing

    func testSmoothingReducesSuddenChanges() {
        let smoothed = VoiceAudioUtils.smoothLevel(current: 0.2, new: 1.0)

        // Should be between current and new, closer to current
        XCTAssertTrue(smoothed > 0.2)
        XCTAssertTrue(smoothed < 1.0)
        XCTAssertEqual(smoothed, 0.44, accuracy: 0.001)
    }

    func testSmoothingFromZero() {
        let smoothed = VoiceAudioUtils.smoothLevel(current: 0.0, new: 1.0)
        XCTAssertEqual(smoothed, 0.3)
    }

    func testSmoothingMaintainsStableLevel() {
        let smoothed = VoiceAudioUtils.smoothLevel(current: 0.5, new: 0.5)
        XCTAssertEqual(smoothed, 0.5)
    }
}
