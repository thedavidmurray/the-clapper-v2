import SwiftUI

/// 3-sample custom gesture training flow.
struct GestureTrainingView: View {
    @ObservedObject var gestureMatcher: GestureMatcher
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var gestureName = ""
    @State private var isRecording = false
    @State private var sampleIndex = 0
    @State private var samples: [[PeakDetector.DetectedPeak]] = []
    @State private var validationMessage = "Record 3 samples to validate."
    @State private var isValidPattern = false
    @State private var savedGesture: GestureMatcher.Gesture?

    @State private var timer: Timer?
    @State private var remainingSeconds = 0

    private let requiredSamples = 3
    private let validationThreshold = 0.2
    private let dtw = DTWEngine()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                instructions

                TextField("Gesture name", text: $gestureName)
                    .textFieldStyle(.roundedBorder)

                progress

                recordButton

                validationStatus

                Button("Save Gesture", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)

                Spacer()
            }
            .padding()
            .navigationTitle("Train Gesture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clap 3 times in your pattern")
                .font(.headline)
            Text("1) Record sample 1/3")
            Text("2) Record sample 2/3")
            Text("3) Record sample 3/3")
            Text("All samples must match within DTW distance < \(String(format: "%.1f", validationThreshold)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var progress: some View {
        HStack(spacing: 10) {
            ForEach(0..<requiredSamples, id: \.self) { idx in
                Circle()
                    .fill(idx < samples.count ? Color.green : (idx == sampleIndex ? Color.blue : Color.gray.opacity(0.3)))
                    .frame(width: 14, height: 14)
            }
            Spacer()
            Text("\(samples.count)/\(requiredSamples)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recordButton: some View {
        Button(action: recordSample) {
            VStack(spacing: 6) {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 40))
                Text(isRecording ? "Recording... \(remainingSeconds)s" : "Record Sample \(min(sampleIndex + 1, requiredSamples))/3")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isRecording ? Color.red : Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(14)
        }
        .disabled(isRecording || samples.count >= requiredSamples)
    }

    private var validationStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(validationMessage)
                .font(.subheadline)
                .foregroundStyle(isValidPattern ? .green : .secondary)

            if let savedGesture {
                Text("Saved: \(savedGesture.name)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSave: Bool {
        isValidPattern && !gestureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && savedGesture == nil
    }

    private func recordSample() {
        guard storeManager.isFeatureAvailable(.customGestures) else {
            validationMessage = "Custom gesture training requires Premium."
            return
        }

        isRecording = true
        remainingSeconds = 3
        let base = Date()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            remainingSeconds -= 1
            if remainingSeconds <= 0 {
                t.invalidate()
                finishRecording(base: base)
            }
        }
    }

    private func finishRecording(base: Date) {
        isRecording = false

        // Demo capture for now: deterministic clap-like pattern + slight jitter.
        let jitter = Double.random(in: -0.035...0.035)
        let points = [0.0, 0.28 + jitter, 0.60 + jitter]

        let captured = points.map { offset in
            PeakDetector.DetectedPeak(
                timestamp: base.addingTimeInterval(offset),
                amplitude: 0.8,
                frequency: 3400,
                type: .clap,
                confidence: 0.9,
                frequencyProfile: [0.4, 0.7, 0.6, 0.2]
            )
        }

        samples.append(captured)
        sampleIndex = min(samples.count, requiredSamples - 1)

        if samples.count == requiredSamples {
            validateSamples()
        } else {
            validationMessage = "Sample \(samples.count) recorded."
        }
    }

    private func validateSamples() {
        guard samples.count == requiredSamples else {
            isValidPattern = false
            return
        }

        let d12 = dtw.compare(samples1: samples[0], samples2: samples[1])
        let d23 = dtw.compare(samples1: samples[1], samples2: samples[2])
        let d13 = dtw.compare(samples1: samples[0], samples2: samples[2])

        let maxDistance = max(d12, max(d23, d13))
        isValidPattern = maxDistance < validationThreshold

        if isValidPattern {
            validationMessage = "Validation passed (max distance: \(String(format: "%.3f", maxDistance)))."
        } else {
            validationMessage = "Samples are inconsistent (max distance: \(String(format: "%.3f", maxDistance))). Retake all samples."
            samples.removeAll()
            sampleIndex = 0
        }
    }

    private func save() {
        let trimmed = gestureName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let gesture = gestureMatcher.trainCustomGesture(name: trimmed, samples: samples) else {
            validationMessage = "Could not save gesture. Try recording again."
            return
        }

        savedGesture = gesture
        IntentDispatcher.shared.dispatchGestureIntent(.custom)
        validationMessage = "Gesture saved and App Intent binding updated."
    }
}

#Preview {
    GestureTrainingView(gestureMatcher: GestureMatcher(), storeManager: StoreManager())
}
