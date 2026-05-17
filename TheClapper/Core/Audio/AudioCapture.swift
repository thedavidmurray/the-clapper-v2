import Foundation
import AVFoundation
import Accelerate

/// Real-time audio capture with FFT analysis for gesture detection
/// Main actor wrapper around AudioEngine for UI integration
@MainActor
class AudioCapture: ObservableObject {
    @Published var isListening = false
    @Published var currentAmplitude: Float = 0.0
    
    /// Callback when a peak is detected during gesture training
    var onPeakDetected: ((PeakDetector.DetectedPeak) -> Void)?
    
    private var audioEngine: AVAudioEngine?
    private let fftProcessor = FFTProcessor()
    private let peakDetector = PeakDetector()
    
    // MARK: - Configuration
    private let sampleRate: Double = 16000.0
    private let bufferSize: UInt32 = 1024
    
    enum AudioError: Error {
        case permissionDenied
        case engineInitFailed
    }

    /// Start listening for gestures
    func startCapture() throws {
        let session = AVAudioSession.sharedInstance()
        guard session.recordPermission == .granted else {
            throw AudioError.permissionDenied
        }
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Downsample to 16kHz if needed
        let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) ?? format
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, format: desiredFormat)
        }
        
        try audioEngine.start()
        isListening = true
    }
    
    /// Stop listening
    func stopCapture() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isListening = false
    }
    
    // MARK: - Private
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Convert to array for processing
        var samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        // Downsample if necessary
        if format.sampleRate != sampleRate {
            samples = downsample(samples, from: format.sampleRate, to: sampleRate)
        }
        
        // Perform FFT
        let fft = fftProcessor.performFFT(on: samples)
        
        // Calculate amplitude
        let amplitude = calculateAmplitude(from: samples)
        DispatchQueue.main.async { [weak self] in
            self?.currentAmplitude = amplitude
        }
        
        // Detect peaks (potential claps/snaps)
        if let peak = peakDetector.detectPeak(in: fft, amplitude: amplitude) {
            // Fire callback for training
            DispatchQueue.main.async { [weak self] in
                self?.onPeakDetected?(peak)
            }
        }
    }
    
    private func downsample(_ samples: [Float], from: Double, to: Double) -> [Float] {
        let ratio = from / to
        let newLength = Int(Double(samples.count) / ratio)
        var downsampled = [Float](repeating: 0, count: newLength)
        
        for i in 0..<newLength {
            let index = Int(Double(i) * ratio)
            downsampled[i] = samples[min(index, samples.count - 1)]
        }
        
        return downsampled
    }
    
    private func calculateAmplitude(from samples: [Float]) -> Float {
        var sum: Float = 0
        for sample in samples {
            sum += abs(sample)
        }
        return sum / Float(samples.count)
    }
}
