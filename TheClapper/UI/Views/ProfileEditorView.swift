import SwiftUI
import CoreLocation

/// UI for editing gesture profiles and their triggers
struct ProfileEditorView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProfile: Profile?
    @State private var isAddingProfile = false
    @State private var newProfileName = ""
    @State private var newProfileIcon = "house.fill"
    
    let availableIcons = [
        "house.fill", "briefcase.fill", "dumbbell.fill", "paintbrush.fill",
        "car.fill", "bed.double.fill", "desktopcomputer", "headphones",
        "music.note", "camera.fill", "figure.walk", "sun.max.fill"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Active Profile") {
                    ProfileRow(
                        profile: profileManager.activeProfile,
                        isActive: true,
                        isPremium: storeManager.isPremium
                    )
                }
                
                Section("All Profiles") {
                    ForEach(profileManager.profiles) { profile in
                        Button(action: { selectedProfile = profile }) {
                            ProfileRow(
                                profile: profile,
                                isActive: profile.id == profileManager.activeProfileId,
                                isPremium: storeManager.isPremium
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if storeManager.isFeatureAvailable(.multipleProfiles) || profileManager.profiles.count < 2 {
                        Button(action: { isAddingProfile = true }) {
                            Label("Add New Profile", systemImage: "plus.circle")
                        }
                    } else {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.orange)
                            Text("Upgrade for more profiles")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Auto-Switching") {
                    Toggle("Enable Auto-Switching", isOn: $profileManager.isAutoSwitching)
                    
                    if !profileManager.isAutoSwitching {
                        Text("Profiles won't automatically change based on location or time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedProfile) { profile in
                ProfileDetailView(
                    profile: profile,
                    profileManager: profileManager,
                    storeManager: storeManager
                )
            }
            .sheet(isPresented: $isAddingProfile) {
                addProfileSheet
            }
        }
    }
    
    // MARK: - Add Profile Sheet
    
    private var addProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Profile Details") {
                    TextField("Name", text: $newProfileName)
                    
                    Picker("Icon", selection: $newProfileIcon) {
                        ForEach(availableIcons, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                Text(icon.replacingOccurrences(of: ".fill", with: ""))
                            }
                            .tag(icon)
                        }
                    }
                }
                
                Section("Preview") {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: newProfileIcon)
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)
                            Text(newProfileName.isEmpty ? "New Profile" : newProfileName)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isAddingProfile = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProfile()
                    }
                    .disabled(newProfileName.isEmpty)
                }
            }
        }
    }
    
    private func createProfile() {
        let _ = profileManager.createProfile(
            name: newProfileName,
            icon: newProfileIcon
        )
        newProfileName = ""
        isAddingProfile = false
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: Profile
    let isActive: Bool
    let isPremium: Bool
    
    var body: some View {
        HStack {
            Image(systemName: profile.icon)
                .font(.title3)
                .foregroundStyle(isActive ? .blue : .gray)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text("\(profile.gestures.count) gestures")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let trigger = profile.trigger, trigger.isEnabled {
                        Image(systemName: triggerIcon(for: trigger))
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func triggerIcon(for trigger: Profile.Trigger) -> String {
        switch trigger.type {
        case .location: return "location.fill"
        case .time: return "clock.fill"
        }
    }
}

// MARK: - Profile Detail View

struct ProfileDetailView: View {
    let profile: Profile
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingTriggerEditor = false
    @State private var selectedTrigger: TriggerType?
    
    enum TriggerType {
        case location
        case time
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: profile.icon)
                                .font(.system(size: 64))
                                .foregroundStyle(.blue)
                            Text(profile.name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
                
                Section("Gesture Bindings") {
                    if profile.gestures.isEmpty {
                        Text("No gesture bindings configured")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(profile.gestures, id: \.gestureType) { binding in
                            GestureBindingRow(binding: binding)
                        }
                    }
                    
                    Button("Add Gesture Binding") {
                        // Would show gesture picker
                    }
                }
                
                Section("Auto-Switch Trigger") {
                    if let trigger = profile.trigger, trigger.isEnabled {
                        TriggerSummaryRow(trigger: trigger)
                        
                        Button("Change Trigger") {
                            showingTriggerEditor = true
                        }
                        
                        Button("Remove Trigger", role: .destructive) {
                            profileManager.updateTrigger(for: profile.id, trigger: nil)
                        }
                    } else {
                        Text("No auto-switch trigger set")
                            .foregroundStyle(.secondary)
                        
                        Button("Add Location Trigger") {
                            selectedTrigger = .location
                            showingTriggerEditor = true
                        }
                        
                        Button("Add Time Trigger") {
                            selectedTrigger = .time
                            showingTriggerEditor = true
                        }
                    }
                }
                
                if profileManager.profiles.count > 1 {
                    Section {
                        Button("Delete Profile", role: .destructive) {
                            profileManager.deleteProfile(id: profile.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTriggerEditor) {
                TriggerEditorView(
                    profileId: profile.id,
                    profileManager: profileManager,
                    initialType: selectedTrigger
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct GestureBindingRow: View {
    let binding: Profile.GestureBinding
    
    var body: some View {
        HStack {
            Image(systemName: iconForGesture(binding.gestureType))
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text(nameForGesture(binding.gestureType))
                    .font(.subheadline)
                
                Text(actionDescription(binding.action))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func iconForGesture(_ type: GestureType) -> String {
        switch type {
        case .singleClap: return "hand.tap"
        case .doubleClap: return "hand.tap.fill"
        case .tripleClap: return "hands.clap.fill"
        case .singleSnap: return "sparkles"
        case .doubleSnap: return "sparkles"
        case .custom: return "star"
        }
    }
    
    private func nameForGesture(_ type: GestureType) -> String {
        switch type {
        case .singleClap: return "Single Clap"
        case .doubleClap: return "Double Clap"
        case .tripleClap: return "Triple Clap"
        case .singleSnap: return "Single Snap"
        case .doubleSnap: return "Double Snap"
        case .custom: return "Custom Gesture"
        }
    }
    
    private func actionDescription(_ action: Profile.GestureAction) -> String {
        switch action {
        case .shortcut(let name): return "Runs '\(name)' shortcut"
        case .url(let url): return "Opens \(url)"
        case .camera: return "Opens Camera"
        case .flashlight: return "Toggles Flashlight"
        case .custom(let id): return "Custom action '\(id)'"
        }
    }
}

struct TriggerSummaryRow: View {
    let trigger: Profile.Trigger
    
    var body: some View {
        HStack {
            Image(systemName: iconForTrigger)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text(titleForTrigger)
                    .font(.subheadline)
                
                Text(subtitleForTrigger)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if trigger.isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
    
    private var iconForTrigger: String {
        switch trigger.type {
        case .location: return "location.fill"
        case .time: return "clock.fill"
        }
    }
    
    private var titleForTrigger: String {
        switch trigger.type {
        case .location: return "Location Based"
        case .time: return "Time Based"
        }
    }
    
    private var subtitleForTrigger: String {
        switch trigger.type {
        case .location(_, _, let radius):
            return "Within \(Int(radius))m of location"
        case .time(let start, let end, _):
            return "\(start):00 - \(end):00"
        }
    }
}

// MARK: - Trigger Editor

struct TriggerEditorView: View {
    let profileId: UUID
    @ObservedObject var profileManager: ProfileManager
    let initialType: ProfileDetailView.TriggerType?
    @Environment(\.dismiss) private var dismiss
    
    @State private var triggerType: ProfileDetailView.TriggerType = .location
    @State private var locationRadius: Double = 100
    @State private var startHour = 9
    @State private var endHour = 17
    @State private var selectedDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
    
    let weekdays = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Trigger Type", selection: $triggerType) {
                    Text("Location").tag(ProfileDetailView.TriggerType.location)
                    Text("Time").tag(ProfileDetailView.TriggerType.time)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                
                if triggerType == .location {
                    Section("Location") {
                        Text("Current location will be captured when you save")
                            .foregroundStyle(.secondary)
                        
                        Slider(value: $locationRadius, in: 50...500, step: 50) {
                            Text("Radius")
                        }
                        
                        HStack {
                            Text("Radius: \(Int(locationRadius)) meters")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                } else {
                    Section("Time Range") {
                        Picker("Start Hour", selection: $startHour) {
                            ForEach(0..<24) { hour in
                                Text("\(hour):00").tag(hour)
                            }
                        }
                        
                        Picker("End Hour", selection: $endHour) {
                            ForEach(0..<24) { hour in
                                Text("\(hour):00").tag(hour)
                            }
                        }
                    
                    Section("Active Days") {
                        ForEach(weekdays, id: \.0) { day, label in
                            Toggle(label, isOn: Binding(
                                get: { selectedDays.contains(day) },
                                set: { isOn in
                                    if isOn {
                                        selectedDays.insert(day)
                                    } else {
                                        selectedDays.remove(day)
                                    }
                                }
                            ))
                        }
                    }
                }
            }
            }
            .navigationTitle("Edit Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTrigger()
                    }
                    .disabled(triggerType == .time && selectedDays.isEmpty)
                }
            }
            .onAppear {
                if let initial = initialType {
                    switch initial {
                    case .location: triggerType = .location
                    case .time: triggerType = .time
                    }
                }
            }
        }
    }
    
    private func saveTrigger() {
        let trigger: Profile.Trigger
        
        switch triggerType {
        case .location:
            // In real app, get actual current location
            trigger = Profile.Trigger(
                type: .location(
                    latitude: 37.7749,  // Default/SF
                    longitude: -122.4194,
                    radius: locationRadius
                ),
                isEnabled: true
            )
            
        case .time:
            trigger = Profile.Trigger(
                type: .time(
                    startHour: startHour,
                    endHour: endHour,
                    days: Array(selectedDays)
                ),
                isEnabled: true
            )
        }
        
        profileManager.updateTrigger(for: profileId, trigger: trigger)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ProfileEditorView(
        profileManager: ProfileManager(),
        storeManager: StoreManager()
    )
}
