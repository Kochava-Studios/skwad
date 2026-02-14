import Foundation
import AVFoundation
import Speech
import CoreVideo
import QuartzCore
import Observation

/// Manages voice input using Apple's speech recognition
@Observable
@MainActor
final class VoiceInputManager {
    static let shared = VoiceInputManager()

    var isListening = false
    var transcribedText = ""
    var error: String?
    var audioLevel: Float = 0
    var waveformSamples: [Float] = Array(repeating: 0, count: 64)

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    private let settings = AppSettings.shared

    // Waveform interpolation state
    private let sampleCount = 64
    private var previousSamples: [Float] = []
    private var currentSamples: [Float] = []
    private var displayLink: CVDisplayLink?
    private var lastSampleTime: CFTimeInterval = 0
    private let sampleInterval: CFTimeInterval = 0.1  // 100ms between samples (like Witsy)

    private init() {
        // Skip expensive initialization in Xcode Previews
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        setupDisplayLink()
    }

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let manager = Unmanaged<VoiceInputManager>.fromOpaque(userInfo!).takeUnretainedValue()
            Task { @MainActor in
                manager.interpolateWaveform()
            }
            return kCVReturnSuccess
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, userInfo)
    }

    private func startDisplayLink() {
        guard let displayLink = displayLink else { return }
        CVDisplayLinkStart(displayLink)
    }

    private func stopDisplayLink() {
        guard let displayLink = displayLink else { return }
        CVDisplayLinkStop(displayLink)
    }

    private func interpolateWaveform() {
        guard isListening else { return }

        let now = CACurrentMediaTime()
        let elapsed = now - lastSampleTime
        let rawProgress = Float(min(1.0, elapsed / sampleInterval))
        let progress = VoiceAudioUtils.easeOut(rawProgress)

        waveformSamples = VoiceAudioUtils.interpolate(
            previous: previousSamples,
            current: currentSamples,
            progress: progress
        )
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        // Request microphone permission first
        let micStatus = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micStatus else {
            error = "Microphone access denied. Enable in System Settings > Privacy & Security > Microphone."
            return false
        }

        // Check/request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            break
        case .denied:
            error = "Speech recognition denied. Enable in System Settings > Privacy & Security > Speech Recognition."
            return false
        case .restricted:
            error = "Speech recognition is restricted on this device."
            return false
        case .notDetermined:
            error = "Speech recognition permission not determined."
            return false
        @unknown default:
            error = "Speech recognition unavailable."
            return false
        }

        return true
    }

    // MARK: - Recording

    func startListening() async {
        guard settings.voiceEnabled else { return }

        // Check authorization
        guard await requestAuthorization() else { return }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognition not available"
            return
        }

        // Stop any existing recognition
        stopListening()

        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        // Get input node and set up format
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Verify we have a valid format
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            error = "Invalid audio format. Check microphone settings."
            return
        }

        // Install tap with larger buffer for better recognition
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)

            // Process audio level on background then update UI
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            if let channelData = channelData, frameLength > 0 {
                // Copy data we need before leaving this scope
                var samples = [Float](repeating: 0, count: frameLength)
                for i in 0..<frameLength {
                    samples[i] = channelData[i]
                }
                Task { @MainActor in
                    self.processAudioSamples(samples)
                }
            }
        }

        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            transcribedText = ""
            error = nil
            audioLevel = 0
            previousSamples = Array(repeating: 0, count: sampleCount)
            currentSamples = Array(repeating: 0, count: sampleCount)
            waveformSamples = Array(repeating: 0, count: sampleCount)
            lastSampleTime = CACurrentMediaTime()
            startDisplayLink()
        } catch let audioError as NSError {
            if audioError.domain == NSOSStatusErrorDomain && audioError.code == -10878 {
                self.error = "Microphone access denied. Enable in System Settings > Privacy & Security > Microphone."
            } else {
                self.error = "Failed to start audio: \(audioError.localizedDescription)"
            }
            return
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if let error = error {
                    let nsError = error as NSError
                    // Ignore cancellation errors (1) and "no speech detected" during active listening (216, 1110)
                    if nsError.code != 1 && nsError.code != 216 && nsError.code != 1110 {
                        self.error = error.localizedDescription
                    }
                }
            }
        }
    }

    func stopListening() {
        stopDisplayLink()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        audioLevel = 0
        previousSamples = []
        currentSamples = []
        waveformSamples = Array(repeating: 0, count: sampleCount)
    }

    // MARK: - Audio Level & Waveform

    private func processAudioSamples(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        let level = VoiceAudioUtils.calculateLevel(from: samples)
        self.audioLevel = VoiceAudioUtils.smoothLevel(current: self.audioLevel, new: level)

        let newSamples = VoiceAudioUtils.downsample(samples, to: sampleCount)

        // Update interpolation state - shift current to previous, set new current
        previousSamples = currentSamples
        currentSamples = newSamples
        lastSampleTime = CACurrentMediaTime()
    }

    // MARK: - Text Injection

    func injectText(_ text: String, into agentManager: AgentManager, submit: Bool = false) {
        guard !text.isEmpty else { return }
        guard let agentId = agentManager.activeAgentId else { return }

        if submit {
            agentManager.injectText(text, for: agentId)
        } else {
            agentManager.sendText(text, for: agentId)
        }
    }
}
