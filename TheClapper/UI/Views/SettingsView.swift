import SwiftUI
import AVFoundation
import CoreLocation

/// Settings view for permission management and app configuration
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var micPermissionStatus: AVAudioSession.RecordPermission = .undetermined
    @State private var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @State private var notificationsEnabled = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    PermissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        status: micStatusText,
                        statusColor: micStatusColor,
                        action: requestMicrophonePermission
                    )
                    
                    PermissionRow(
                        icon: "location.fill",
                        title: "Location",
                        status: locationStatusText,
                        statusColor: locationStatusColor,
                        action: requestLocationPermission
                    )
                    
                    PermissionRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        status: notificationsEnabled ? "Enabled" : "Not requested",
                        statusColor: notificationsEnabled ? .green : .gray,
                        action: requestNotificationPermission
                    )
                }
                
                Section("Security") {
                    NavigationLink {
                        SecurityInfoView()
                    } label: {
                        Label("Data Storage", systemImage: "lock.shield.fill")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshPermissionStatus()
            }
        }
    }
    
    private func refreshPermissionStatus() {
        micPermissionStatus = AVAudioSession.sharedInstance().recordPermission
        locationPermissionStatus = CLLocationManager().authorizationStatus
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func requestMicrophonePermission() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.requestMicrophonePermission { granted in
            refreshPermissionStatus()
        }
    }
    
    private func requestLocationPermission() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            refreshPermissionStatus()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationsEnabled = granted
            }
        }
    }
    
    private var micStatusText: String {
        switch micPermissionStatus {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .undetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }
    
    private var micStatusColor: Color {
        switch micPermissionStatus {
        case .granted: return .green
        case .denied: return .red
        case .undetermined: return .gray
        @unknown default: return .gray
        }
    }
    
    private var locationStatusText: String {
        switch locationPermissionStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "Granted"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }
    
    private var locationStatusColor: Color {
        switch locationPermissionStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .gray
        @unknown default: return .gray
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let status: String
    let statusColor: Color
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            
            Spacer()
            
            Button("Request") {
                action()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(status == "Granted")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Security Info View

struct SecurityInfoView: View {
    var body: some View {
        List {
            Section("Data Protection") {
                VStack(alignment: .leading, spacing: 12) {
                    SecurityFeatureRow(
                        icon: "lock.fill",
                        title: "Encrypted Profiles",
                        description: "Profile data stored with iOS File Protection"
                    )
                    SecurityFeatureRow(
                        icon: "hand.raised.fill",
                        title: "URL Whitelist",
                        description: "Only https, http, and shortcuts schemes allowed"
                    )
                    SecurityFeatureRow(
                        icon: "eye.slash.fill",
                        title: "Gesture Privacy",
                        description: "Custom gesture templates stored in app sandbox"
                    )
                }
                .padding(.vertical, 8)
            }
            
            Section("Best Practices") {
                Text("The Clapper uses on-device processing for gesture recognition. Audio data never leaves your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Security")
    }
}

struct SecurityFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}
