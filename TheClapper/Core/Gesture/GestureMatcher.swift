import Foundation

/// Matches detected audio peaks against known gesture templates
@MainActor
class GestureMatcher: ObservableObject {
    @Published var knownGestures: [Gesture] = []
    @Published var lastMatchedGesture: GestureType?
    
    private let templateStore = TemplateStore()
    private let dtwEngine = DTWEngine()
    private var recentPeaks: [PeakDetector.DetectedPeak] = []
    private let patternWindow: TimeInterval = 1.5 // 1.5s window for multi-gesture patterns
    
    struct Gesture: Identifiable, Codable {
        let id: UUID
        var name: String
        var type: GestureType
        var template: GestureTemplate
        var isCustom: Bool
        var createdAt: Date
    }
    
    struct GestureTemplate: Codable {
        let peakCount: Int
        let timingPattern: [Double] // Relative timings between peaks
        let frequencySignature: [Float] // Average frequency profile
        let confidenceThreshold: Double
    }
    
    init() {
        // Load built-in gestures
        loadBuiltInGestures()
        
        // Load custom gestures from storage
        knownGestures.append(contentsOf: templateStore.loadCustomGestures())
    }
    
    /// Match a detected peak against known gestures
    func matchGesture(_ peak: PeakDetector.DetectedPeak) -> GestureType? {
        // Add to recent peaks buffer
        recentPeaks.append(peak)
        
        // Clean old peaks outside window
        let cutoff = Date().addingTimeInterval(-patternWindow)
        recentPeaks.removeAll { $0.timestamp < cutoff }
        
        // Try matching based on recent peak sequence
        guard let matched = findMatchingGesture() else {
            return nil
        }
        
        lastMatchedGesture = matched.type
        return matched.type
    }
    
    /// Train a custom gesture from 3 sample patterns
    func trainCustomGesture(name: String, samples: [[PeakDetector.DetectedPeak]]) -> Gesture? {
        guard samples.count == 3 else { return nil }
        
        // Validate all samples have same structure
        let peakCounts = samples.map { $0.count }
        guard Set(peakCounts).count == 1, peakCounts[0] > 0 else { return nil }
        
        // Create averaged template
        let template = createTemplate(from: samples)
        
        let gesture = Gesture(
            id: UUID(),
            name: name,
            type: .custom,
            template: template,
            isCustom: true,
            createdAt: Date()
        )
        
        // Save
        knownGestures.append(gesture)
        templateStore.saveCustomGesture(gesture)
        
        return gesture
    }
    
    /// Delete a custom gesture
    func deleteCustomGesture(id: UUID) {
        knownGestures.removeAll { $0.id == id && $0.isCustom }
        templateStore.deleteCustomGesture(id: id)
    }
    
    // MARK: - Private
    
    private func loadBuiltInGestures() {
        // Single clap: 1 peak, clap type
        let singleClap = Gesture(
            id: UUID(),
            name: "Single Clap",
            type: .singleClap,
            template: GestureTemplate(
                peakCount: 1,
                timingPattern: [0],
                frequencySignature: [],
                confidenceThreshold: 0.6
            ),
            isCustom: false,
            createdAt: Date()
        )
        
        // Double clap: 2 peaks, ~0.3s apart
        let doubleClap = Gesture(
            id: UUID(),
            name: "Double Clap",
            type: .doubleClap,
            template: GestureTemplate(
                peakCount: 2,
                timingPattern: [0, 0.3],
                frequencySignature: [],
                confidenceThreshold: 0.5
            ),
            isCustom: false,
            createdAt: Date()
        )
        
        // Triple clap: 3 peaks, ~0.3s apart
        let tripleClap = Gesture(
            id: UUID(),
            name: "Triple Clap",
            type: .tripleClap,
            template: GestureTemplate(
                peakCount: 3,
                timingPattern: [0, 0.3, 0.6],
                frequencySignature: [],
                confidenceThreshold: 0.5
            ),
            isCustom: false,
            createdAt: Date()
        )
        
        // Single snap: 1 peak, snap type
        let singleSnap = Gesture(
            id: UUID(),
            name: "Single Snap",
            type: .singleSnap,
            template: GestureTemplate(
                peakCount: 1,
                timingPattern: [0],
                frequencySignature: [],
                confidenceThreshold: 0.6
            ),
            isCustom: false,
            createdAt: Date()
        )
        
        // Double snap: 2 peaks, ~0.3s apart
        let doubleSnap = Gesture(
            id: UUID(),
            name: "Double Snap",
            type: .doubleSnap,
            template: GestureTemplate(
                peakCount: 2,
                timingPattern: [0, 0.3],
                frequencySignature: [],
                confidenceThreshold: 0.5
            ),
            isCustom: false,
            createdAt: Date()
        )
        
        knownGestures = [singleClap, doubleClap, tripleClap, singleSnap, doubleSnap]
    }
    
    private func findMatchingGesture() -> Gesture? {
        // Count peaks by type in recent window
        let clapPeaks = recentPeaks.filter { $0.type == .clap }
        let snapPeaks = recentPeaks.filter { $0.type == .snap }
        
        // Simple pattern matching based on count and timing
        for gesture in knownGestures {
            let match = match(gesture: gesture, claps: clapPeaks, snaps: snapPeaks)
            if match {
                return gesture
            }
        }
        
        return nil
    }
    
    private func match(gesture: Gesture, claps: [PeakDetector.DetectedPeak], snaps: [PeakDetector.DetectedPeak]) -> Bool {
        switch gesture.type {
        case .singleClap:
            return claps.count == 1 && snaps.isEmpty
        case .doubleClap:
            return claps.count == 2 && snaps.isEmpty && timingMatch(claps, expected: [0, 0.3])
        case .tripleClap:
            return claps.count == 3 && snaps.isEmpty && timingMatch(claps, expected: [0, 0.3, 0.6])
        case .singleSnap:
            return snaps.count == 1 && claps.isEmpty
        case .doubleSnap:
            return snaps.count == 2 && claps.isEmpty && timingMatch(snaps, expected: [0, 0.3])
        case .custom:
            // Use DTW for custom gestures
            return matchCustom(gesture: gesture, peaks: recentPeaks)
        }
    }
    
    private func timingMatch(_ peaks: [PeakDetector.DetectedPeak], expected: [Double]) -> Bool {
        guard peaks.count == expected.count else { return false }
        
        let actualTimings = peaks.map { $0.timestamp.timeIntervalSince(peaks[0].timestamp) }
        
        for (actual, expected) in zip(actualTimings, expected) {
            if abs(actual - expected) > 0.2 { // 200ms tolerance
                return false
            }
        }
        
        return true
    }
    
    private func matchCustom(gesture: Gesture, peaks: [PeakDetector.DetectedPeak]) -> Bool {
        // Use DTW engine for sophisticated pattern matching
        return dtwEngine.match(
            peaks: peaks,
            template: gesture.template,
            threshold: gesture.template.confidenceThreshold
        )
    }
    
    private func createTemplate(from samples: [[PeakDetector.DetectedPeak]]) -> GestureTemplate {
        let peakCount = samples[0].count
        
        // Average timing patterns
        var avgTimings: [Double] = []
        for i in 0..<peakCount {
            var sum: Double = 0
            for sample in samples {
                if i < sample.count {
                    sum += sample[i].timestamp.timeIntervalSince(sample[0].timestamp)
                }
            }
            avgTimings.append(sum / Double(samples.count))
        }
        
        // Average frequency signatures
        var avgSignature: [Float] = []
        let signatureLength = samples[0].first?.frequencyProfile.count ?? 0
        for i in 0..<signatureLength {
            var sum: Float = 0
            for sample in samples {
                if let firstPeak = sample.first, i < firstPeak.frequencyProfile.count {
                    sum += firstPeak.frequencyProfile[i]
                }
            }
            avgSignature.append(sum / Float(samples.count))
        }
        
        return GestureTemplate(
            peakCount: peakCount,
            timingPattern: avgTimings,
            frequencySignature: avgSignature,
            confidenceThreshold: 0.7 // Custom gestures need higher confidence
        )
    }
}
