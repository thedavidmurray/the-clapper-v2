import Foundation

/// Stores and retrieves gesture templates using JSON file storage
@MainActor
class TemplateStore {
    private let customGesturesKey = "customGestures_v1"
    private let fileManager = FileManager.default
    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("TheClapper", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.complete])
        }
        return appDir.appendingPathComponent("gestures.json")
    }
    
    /// Load custom gestures from storage
    func loadCustomGestures() -> [GestureMatcher.Gesture] {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([GestureMatcher.Gesture].self, from: data) else {
            return []
        }
        return decoded
    }
    
    /// Save a custom gesture to storage
    func saveCustomGesture(_ gesture: GestureMatcher.Gesture) {
        var existing = loadCustomGestures()
        existing.append(gesture)
        saveAll(existing)
    }
    
    /// Delete a custom gesture from storage
    func deleteCustomGesture(id: UUID) {
        var existing = loadCustomGestures()
        existing.removeAll { $0.id == id }
        saveAll(existing)
    }
    
    private func saveAll(_ gestures: [GestureMatcher.Gesture]) {
        guard let data = try? JSONEncoder().encode(gestures) else { return }
        try? data.write(to: storageURL, options: .completeFileProtection)
    }
}
