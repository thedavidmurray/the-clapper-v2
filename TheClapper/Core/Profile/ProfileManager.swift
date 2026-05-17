import Foundation
import CoreLocation
import Combine
import UIKit

/// Manages context-based gesture profiles with optional auto-switching
@MainActor
final class ProfileManager: NSObject, ObservableObject {
    @Published var profiles: [Profile]
    @Published var activeProfileId: UUID
    @Published var isAutoSwitching = true

    private var locationManager: CLLocationManager?
    private var timer: Timer?

    var activeProfile: Profile {
        profiles.first(where: { $0.id == activeProfileId }) ?? profiles[0]
    }

    override init() {
        let defaults = Self.defaultProfiles()
        self.profiles = defaults
        self.activeProfileId = defaults[0].id

        super.init()

        loadSavedProfiles()
        setupAutoSwitching()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - CRUD

    @discardableResult
    func createProfile(name: String, icon: String = "house.fill") -> Profile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = String(trimmed.prefix(50))
        let finalName = sanitized.isEmpty ? "New Profile" : sanitized
        let profile = Profile(id: UUID(), name: finalName, icon: icon, gestures: [], trigger: nil)
        profiles.append(profile)
        saveProfiles()
        return profile
    }

    func deleteProfile(id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        if activeProfileId == id, let first = profiles.first {
            activeProfileId = first.id
        }
        saveProfiles()
    }

    func switchToProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileId = id

        isAutoSwitching = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3600) { [weak self] in
            self?.isAutoSwitching = true
        }

        saveProfiles()
    }

    func updateTrigger(for profileId: UUID, trigger: Profile.Trigger?) {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        profiles[index].trigger = trigger
        saveProfiles()
        setupLocationMonitoringIfNeeded()
    }

    func addGestureBinding(to profileId: UUID, gesture: GestureType, action: Profile.GestureAction) {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        profiles[index].gestures.append(Profile.GestureBinding(gestureType: gesture, action: action))
        saveProfiles()
    }

    func removeGestureBinding(from profileId: UUID, gesture: GestureType) {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        profiles[index].gestures.removeAll { $0.gestureType == gesture }
        saveProfiles()
    }

    // MARK: - Gesture Execution

    func triggerAction(for gesture: GestureType) {
        guard let binding = activeProfile.gestures.first(where: { $0.gestureType == gesture }) else { return }
        executeAction(binding.action)
    }

    private func executeAction(_ action: Profile.GestureAction) {
        switch action {
        case .shortcut(let name):
            ShortcutRunner.shared.runShortcut(named: name)

        case .url(let urlString):
            guard let url = URL(string: urlString) else { return }
            let allowedSchemes = ["https", "http", "shortcuts"]
            guard let scheme = url.scheme?.lowercased(),
                  allowedSchemes.contains(scheme) else { return }
            UIApplication.shared.open(url)

        case .camera:
            NotificationCenter.default.post(name: .openCamera, object: nil)

        case .flashlight:
            FlashlightController.shared.toggle()

        case .custom(let identifier):
            NotificationCenter.default.post(name: .customGestureAction, object: identifier)
        }
    }

    // MARK: - Auto Switching

    private func setupAutoSwitching() {
        setupLocationMonitoringIfNeeded()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTimeTriggers()
            }
        }

        checkTimeTriggers()
    }

    private func setupLocationMonitoringIfNeeded() {
        let hasLocationTrigger = profiles.contains { profile in
            guard let trigger = profile.trigger, trigger.isEnabled else { return false }
            if case .location = trigger.type { return true }
            return false
        }

        guard hasLocationTrigger else {
            locationManager?.stopMonitoringSignificantLocationChanges()
            return
        }

        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.requestWhenInUseAuthorization()
        }

        locationManager?.startMonitoringSignificantLocationChanges()
    }

    private func checkTimeTriggers() {
        guard isAutoSwitching else { return }

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let weekday = Calendar.current.component(.weekday, from: now)

        for profile in profiles {
            guard let trigger = profile.trigger, trigger.isEnabled else { continue }
            guard case .time(let startHour, let endHour, let days) = trigger.type else { continue }

            let inHourRange = hour >= startHour && hour < endHour
            let inDayRange = days.contains(weekday)
            guard inHourRange, inDayRange else { continue }

            if activeProfileId != profile.id {
                activeProfileId = profile.id
                notifyProfileSwitch(profile)
            }
            return
        }
    }

    private func checkLocationTriggers(with location: CLLocation) {
        guard isAutoSwitching else { return }

        for profile in profiles {
            guard let trigger = profile.trigger, trigger.isEnabled else { continue }
            guard case .location(let latitude, let longitude, let radius) = trigger.type else { continue }

            let target = CLLocation(latitude: latitude, longitude: longitude)
            if location.distance(from: target) <= radius {
                if activeProfileId != profile.id {
                    activeProfileId = profile.id
                    notifyProfileSwitch(profile)
                }
                return
            }
        }
    }

    private func notifyProfileSwitch(_ profile: Profile) {
        NotificationCenter.default.post(name: .profileDidSwitch, object: profile)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Persistence

    private var profilesStorageURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("TheClapper", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.complete])
        }
        return appDir.appendingPathComponent("profiles.json")
    }

    private func saveProfiles() {
        guard let encoded = try? JSONEncoder().encode(profiles) else { return }
        try? encoded.write(to: profilesStorageURL, options: .completeFileProtection)
        UserDefaults.standard.set(activeProfileId.uuidString, forKey: "active_profile_id")
    }

    private func loadSavedProfiles() {
        guard let data = try? Data(contentsOf: profilesStorageURL),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data),
              !decoded.isEmpty else {
            return
        }

        profiles = decoded

        if let activeIdString = UserDefaults.standard.string(forKey: "active_profile_id"),
           let activeId = UUID(uuidString: activeIdString),
           profiles.contains(where: { $0.id == activeId }) {
            activeProfileId = activeId
        } else if let first = profiles.first {
            activeProfileId = first.id
        }
    }

    private static func defaultProfiles() -> [Profile] {
        [
            Profile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Home",
                icon: "house.fill",
                gestures: [
                    Profile.GestureBinding(gestureType: .doubleClap, action: .shortcut("Lights Toggle")),
                    Profile.GestureBinding(gestureType: .singleSnap, action: .custom("music_pause"))
                ],
                trigger: nil
            ),
            Profile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Office",
                icon: "briefcase.fill",
                gestures: [
                    Profile.GestureBinding(gestureType: .singleClap, action: .shortcut("Mute Toggle")),
                    Profile.GestureBinding(gestureType: .singleSnap, action: .shortcut("Next Slide"))
                ],
                trigger: Profile.Trigger(type: .time(startHour: 9, endHour: 18, days: [2, 3, 4, 5, 6]), isEnabled: true)
            ),
            Profile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Gym",
                icon: "dumbbell.fill",
                gestures: [
                    Profile.GestureBinding(gestureType: .doubleClap, action: .shortcut("Start Timer")),
                    Profile.GestureBinding(gestureType: .tripleClap, action: .shortcut("Stop Timer"))
                ],
                trigger: nil
            )
        ]
    }
}

// MARK: - Model

struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var gestures: [GestureBinding]
    var trigger: Trigger?

    struct GestureBinding: Codable {
        let gestureType: GestureType
        let action: GestureAction
    }

    struct Trigger: Codable {
        let type: TriggerType
        let isEnabled: Bool
    }

    enum TriggerType: Codable {
        case location(latitude: Double, longitude: Double, radius: Double)
        case time(startHour: Int, endHour: Int, days: [Int])
    }

    enum GestureAction: Codable {
        case shortcut(String)
        case url(String)
        case camera
        case flashlight
        case custom(String)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let profileDidSwitch = Notification.Name("com.edgeless.clapper.profileDidSwitch")
    static let openCamera = Notification.Name("com.edgeless.clapper.openCamera")
    static let customGestureAction = Notification.Name("com.edgeless.clapper.customGestureAction")
}

// MARK: - Location Delegate

extension ProfileManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.checkLocationTriggers(with: latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Helpers

final class ShortcutRunner {
    static let shared = ShortcutRunner()
    private init() {}

    func runShortcut(named name: String) {
        print("Running shortcut: \(name)")
    }
}

final class FlashlightController {
    static let shared = FlashlightController()
    private init() {}

    func toggle() {
        print("Toggling flashlight")
    }
}
