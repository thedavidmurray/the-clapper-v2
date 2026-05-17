import Foundation

/// Detects transient audio peaks (claps, snaps) from FFT spectrum
class PeakDetector {
    private var lastPeakTime: Date?
    private let cooldownInterval: TimeInterval = 0.2 // 200ms cooldown
    
    // Frequency ranges (bins for 16kHz sample rate, 2048 FFT size)
    private let clapRange: ClosedRange<Int> = 256...640   // 2-5kHz
    private let snapRange: ClosedRange<Int> = 640...1024  // 5-8kHz
    
    // Thresholds (normalized 0-1)
    private let clapThreshold: Float = 0.6
    private let snapThreshold: Float = 0.5
    private let ambientWindowSize = 10
    
    private var ambientHistory: [Float] = []
    private var peakBuffer: [DetectedPeak] = []
    
    struct DetectedPeak {
        let timestamp: Date
        let amplitude: Float
        let frequency: Float
        let type: PeakType
        let confidence: Float
        let frequencyProfile: [Float]
    }
    
    enum PeakType {
        case clap
        case snap
        case unknown
    }
    
    /// Detect if current audio frame contains a valid peak
    func detectPeak(in fftMagnitudes: [Float], amplitude: Float) -> DetectedPeak? {
        // Update ambient noise floor
        updateAmbientLevel(amplitude)
        let ambientLevel = calculateAmbientLevel()
        
        // Check cooldown
        if let lastPeak = lastPeakTime,
           Date().timeIntervalSince(lastPeak) < cooldownInterval {
            return nil
        }
        
        // Analyze frequency ranges
        let clapEnergy = energy(in: clapRange, magnitudes: fftMagnitudes)
        let snapEnergy = energy(in: snapRange, magnitudes: fftMagnitudes)
        
        // Normalize against ambient
        let normalizedClap = clapEnergy / max(ambientLevel, 0.01)
        let normalizedSnap = snapEnergy / max(ambientLevel, 0.01)
        
        // Detect peak type
        let peak: DetectedPeak?
        
        if normalizedClap > clapThreshold && clapEnergy > snapEnergy {
            // Strong clap detected
            let confidence = min(normalizedClap, 1.0)
            let dominantFreq = Float(clapRange.lowerBound + clapRange.upperBound) / 2
            peak = DetectedPeak(
                timestamp: Date(),
                amplitude: clapEnergy,
                frequency: dominantFreq,
                type: .clap,
                confidence: confidence,
                frequencyProfile: Array(fftMagnitudes[clapRange])
            )
        } else if normalizedSnap > snapThreshold && snapEnergy > clapEnergy {
            // Strong snap detected
            let confidence = min(normalizedSnap, 1.0)
            let dominantFreq = Float(snapRange.lowerBound + snapRange.upperBound) / 2
            peak = DetectedPeak(
                timestamp: Date(),
                amplitude: snapEnergy,
                frequency: dominantFreq,
                type: .snap,
                confidence: confidence,
                frequencyProfile: Array(fftMagnitudes[snapRange])
            )
        } else {
            peak = nil
        }
        
        if let detectedPeak = peak {
            lastPeakTime = Date()
            peakBuffer.append(detectedPeak)
            
            // Keep buffer size manageable (last 10 peaks)
            if peakBuffer.count > 10 {
                peakBuffer.removeFirst()
            }
        }
        
        return peak
    }
    
    /// Get recent peaks for pattern matching
    func recentPeaks(since: TimeInterval) -> [DetectedPeak] {
        let cutoff = Date().addingTimeInterval(-since)
        return peakBuffer.filter { $0.timestamp >= cutoff }
    }
    
    /// Clear peak history
    func clearBuffer() {
        peakBuffer.removeAll()
        ambientHistory.removeAll()
    }
    
    // MARK: - Private
    
    private func updateAmbientLevel(_ amplitude: Float) {
        ambientHistory.append(amplitude)
        if ambientHistory.count > ambientWindowSize {
            ambientHistory.removeFirst()
        }
    }
    
    private func calculateAmbientLevel() -> Float {
        guard !ambientHistory.isEmpty else { return 0.1 }
        let sum = ambientHistory.reduce(0, +)
        return sum / Float(ambientHistory.count)
    }
    
    private func energy(in range: ClosedRange<Int>, magnitudes: [Float]) -> Float {
        guard range.lowerBound < magnitudes.count,
              range.upperBound < magnitudes.count else { return 0 }
        
        var sum: Float = 0
        for i in range {
            sum += magnitudes[i] * magnitudes[i]
        }
        return sqrt(sum)
    }
}
