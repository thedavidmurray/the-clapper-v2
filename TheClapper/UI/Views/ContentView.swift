import SwiftUI
import UIKit

/// Main UI: status banner, gesture list, record button, training sheet.
struct ContentView: View {
    @StateObject private var audioCapture = AudioCapture()
    @StateObject private var gestureMatcher = GestureMatcher()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var storeManager = StoreManager()

    @State private var isRecording = false
    @State private var statusMessage = "Listening..."
    @State private var showTraining = false
    @State private var showPaywall = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusBanner

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(gestureMatcher.knownGestures) { gesture in
                            gestureRow(gesture)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Spacer(minLength: 8)

                recordButton
            }
            .padding()
            .navigationTitle("The Clapper v2")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        if storeManager.isFeatureAvailable(.customGestures) {
                            showTraining = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label("Add Gesture", systemImage: "plus.circle.fill")
                    }

                    Button {
                        showPaywall = true
                    } label: {
                        Image(systemName: "crown.fill")
                    }
                    
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showTraining) {
            GestureTrainingView(gestureMatcher: gestureMatcher, storeManager: storeManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(storeManager: storeManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear(perform: setupAudioCallbacks)
        .onDisappear {
            if isRecording {
                audioCapture.stopCapture()
                isRecording = false
            }
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isRecording ? Color.red : Color.green)
                .frame(width: 10, height: 10)

            Text(statusMessage)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Text(profileManager.activeProfile.name)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(999)
        }
        .padding()
        .background(isRecording ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isRecording ? Color.red.opacity(0.35) : Color.green.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private func gestureRow(_ gesture: GestureMatcher.Gesture) -> some View {
        HStack(spacing: 12) {
            Image(systemName: gesture.type.iconName)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(gesture.name)
                    .font(.headline)
                Text("Trigger count: \(triggerCount(for: gesture.type))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if gesture.isCustom {
                Text("CUSTOM")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(.purple)
                    .cornerRadius(999)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 160, height: 160)
                    .shadow(color: (isRecording ? Color.red : Color.blue).opacity(0.35), radius: 16)

                VStack(spacing: 6) {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.largeTitle)
                    Text(isRecording ? "Stop" : "Record Gesture")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }
        }
        .accessibilityLabel(isRecording ? "Stop recording" : "Record gesture")
    }

    private func triggerCount(for type: GestureType) -> Int {
        profileManager.activeProfile.gestures.filter { $0.gestureType == type }.count
    }

    private func toggleRecording() {
        if isRecording {
            audioCapture.stopCapture()
            isRecording = false
            statusMessage = "Listening paused"
            return
        }

        do {
            try audioCapture.startCapture()
            isRecording = true
            statusMessage = "Listening..."
        } catch {
            isRecording = false
            statusMessage = "Microphone error: \(error.localizedDescription)"
        }
    }

    private func setupAudioCallbacks() {
        audioCapture.onPeakDetected = { peak in
            Task { @MainActor in
                guard let gesture = gestureMatcher.matchGesture(peak) else { return }
                statusMessage = "Matched: \(gesture.displayName)"

                profileManager.triggerAction(for: gesture)
                if storeManager.isFeatureAvailable(.shortcutsIntegration) {
                    IntentDispatcher.shared.dispatchGestureIntent(gesture)
                }

                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        }
    }
}

#Preview {
    ContentView()
}
