import Foundation

/// Dynamic Time Warping engine for comparing gesture patterns.
/// Distance score semantics:
/// - 0.0 => identical
/// - < 0.15 => match
/// - > 0.40 => no match
final class DTWEngine {
    let defaultMatchThreshold: Double = 0.15
    let defaultNoMatchThreshold: Double = 0.40

    /// Compare two normalized pattern arrays and return DTW distance.
    func compare(pattern1: [Double], pattern2: [Double]) -> Double {
        if pattern1.isEmpty && pattern2.isEmpty { return 0 }
        guard !pattern1.isEmpty, !pattern2.isEmpty else { return Double.infinity }

        let n = pattern1.count
        let m = pattern2.count

        var cost = Array(
            repeating: Array(repeating: Double.infinity, count: m + 1),
            count: n + 1
        )
        cost[0][0] = 0

        for i in 1...n {
            for j in 1...m {
                let local = abs(pattern1[i - 1] - pattern2[j - 1])
                let bestPrevious = min(
                    cost[i - 1][j],     // insertion
                    cost[i][j - 1],     // deletion
                    cost[i - 1][j - 1]  // match
                )
                cost[i][j] = local + bestPrevious
            }
        }

        return cost[n][m] / Double(max(n, m))
    }

    /// Convenience comparison for peak sequences.
    func compare(samples1: [PeakDetector.DetectedPeak], samples2: [PeakDetector.DetectedPeak]) -> Double {
        compare(pattern1: normalizedTimings(from: samples1), pattern2: normalizedTimings(from: samples2))
    }

    /// Match detected peaks against a trained gesture template.
    func match(
        peaks: [PeakDetector.DetectedPeak],
        template: GestureMatcher.GestureTemplate,
        threshold: Double
    ) -> Bool {
        guard peaks.count >= template.peakCount else { return false }

        let observed = normalizedTimings(from: peaks)
        let expected = normalize(template.timingPattern)
        guard !observed.isEmpty, !expected.isEmpty else { return false }

        let distance = compare(pattern1: observed, pattern2: expected)
        return distance < threshold
    }

    /// Match timing + optional frequency signature.
    func matchWithFrequency(
        peaks: [PeakDetector.DetectedPeak],
        template: GestureMatcher.GestureTemplate,
        threshold: Double
    ) -> Bool {
        let timingDistance = compare(
            pattern1: normalizedTimings(from: peaks),
            pattern2: normalize(template.timingPattern)
        )

        var frequencyDistance: Double = 0
        if !template.frequencySignature.isEmpty,
           let firstPeak = peaks.first,
           !firstPeak.frequencyProfile.isEmpty {
            frequencyDistance = compareFrequencyProfiles(
                detected: firstPeak.frequencyProfile,
                template: template.frequencySignature
            )
        }

        let blended = (timingDistance * 0.7) + (frequencyDistance * 0.3)
        return blended < threshold
    }

    /// Learn a template from 3+ recorded samples.
    func learnTemplate(from samples: [[PeakDetector.DetectedPeak]]) -> GestureMatcher.GestureTemplate? {
        guard samples.count >= 3 else { return nil }

        let normalized = samples.map(normalizedTimings(from:))
        guard let reference = normalized.first, !reference.isEmpty else { return nil }

        let targetLength = reference.count
        let aligned = normalized.map { resize($0, to: targetLength) }

        var averaged = Array(repeating: 0.0, count: targetLength)
        for series in aligned {
            for idx in 0..<targetLength {
                averaged[idx] += series[idx]
            }
        }
        averaged = averaged.map { $0 / Double(aligned.count) }

        let pairwiseDistances = pairwise(aligned).map { compare(pattern1: $0.0, pattern2: $0.1) }
        let meanDistance = pairwiseDistances.isEmpty ? 0 : pairwiseDistances.reduce(0, +) / Double(pairwiseDistances.count)
        let adaptiveThreshold = min(max(0.12 + meanDistance, 0.15), 0.50)

        return GestureMatcher.GestureTemplate(
            peakCount: samples[0].count,
            timingPattern: averaged,
            frequencySignature: [],
            confidenceThreshold: adaptiveThreshold
        )
    }

    // MARK: - Helpers

    private func normalizedTimings(from peaks: [PeakDetector.DetectedPeak]) -> [Double] {
        guard let first = peaks.first else { return [] }
        let raw = peaks.map { $0.timestamp.timeIntervalSince(first.timestamp) }
        return normalize(raw)
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard let maxValue = values.max(), maxValue > 0 else { return values }
        return values.map { $0 / maxValue }
    }

    private func resize(_ values: [Double], to length: Int) -> [Double] {
        guard !values.isEmpty, length > 0 else { return [] }
        if values.count == length { return values }

        let scale = Double(values.count - 1) / Double(max(length - 1, 1))
        return (0..<length).map { idx in
            let source = Double(idx) * scale
            let low = Int(floor(source))
            let high = min(Int(ceil(source)), values.count - 1)
            if low == high { return values[low] }
            let t = source - Double(low)
            return values[low] * (1 - t) + values[high] * t
        }
    }

    private func compareFrequencyProfiles(detected: [Float], template: [Float]) -> Double {
        let count = min(detected.count, template.count)
        guard count > 0 else { return 1 }

        var dot = 0.0
        var magA = 0.0
        var magB = 0.0

        for i in 0..<count {
            let a = Double(detected[i])
            let b = Double(template[i])
            dot += a * b
            magA += a * a
            magB += b * b
        }

        guard magA > 0, magB > 0 else { return 1 }
        let cosine = dot / (sqrt(magA) * sqrt(magB))
        return (1 - cosine) / 2
    }

    private func pairwise<T>(_ values: [T]) -> [(T, T)] {
        guard values.count > 1 else { return [] }
        var result: [(T, T)] = []
        for i in 0..<(values.count - 1) {
            for j in (i + 1)..<values.count {
                result.append((values[i], values[j]))
            }
        }
        return result
    }
}
