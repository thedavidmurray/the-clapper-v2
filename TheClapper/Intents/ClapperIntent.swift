import Foundation
import AppIntents

/// App Intent for triggering actions when gestures are detected
struct ClapperIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Clapper Action"
    static var description = IntentDescription("Trigger an action when a specific gesture is detected")
    
    @Parameter(title: "Gesture")
    var gesture: GestureEntity
    
    @Parameter(title: "Action", default: .toggle)
    var action: ClapperAction
    
    static var parameterSummary: some ParameterSummary {
        Summary("When \(\.$gesture) is detected, \(\.$action)")
    }
    
    func perform() async throws -> some IntentResult {
        // The actual action is handled by Shortcuts automation
        // This intent just provides the trigger point
        return .result(value: "Triggered \(gesture.displayString)")
    }
}

/// Entity representing a detectable gesture
struct GestureEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Gesture"
    
    let id: String
    let displayString: String
    let gestureType: GestureType
    
    static var defaultQuery = GestureQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: displayString))
    }
}

/// Query for available gestures
struct GestureQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [GestureEntity] {
        ClapperShortcutsProvider.allGestures.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [GestureEntity] {
        ClapperShortcutsProvider.allGestures
    }
}

/// Available actions when gesture detected
enum ClapperAction: String, AppEnum {
    case toggle = "toggle"
    case activate = "activate"
    case deactivate = "deactivate"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Action"
    
    static var caseDisplayRepresentations: [ClapperAction: DisplayRepresentation] = [
        .toggle: DisplayRepresentation(title: "Toggle"),
        .activate: DisplayRepresentation(title: "Activate"),
        .deactivate: DisplayRepresentation(title: "Deactivate")
    ]
}

/// Shortcuts provider for App Intents
@available(iOS 16.0, *)
struct ClapperShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ClapperIntent(),
            phrases: [
                "When \(.applicationName) detects a gesture"
            ],
            shortTitle: "Gesture Trigger",
            systemImageName: "hand.wave.fill"
        )
    }
    
    /// All available gestures for Shortcuts
    static let allGestures: [GestureEntity] = [
        GestureEntity(id: "single-clap", displayString: "Single Clap Detected", gestureType: .singleClap),
        GestureEntity(id: "double-clap", displayString: "Double Clap Detected", gestureType: .doubleClap),
        GestureEntity(id: "triple-clap", displayString: "Triple Clap Detected", gestureType: .tripleClap),
        GestureEntity(id: "single-snap", displayString: "Single Snap Detected", gestureType: .singleSnap),
        GestureEntity(id: "double-snap", displayString: "Double Snap Detected", gestureType: .doubleSnap)
    ]
    
    /// Trigger a gesture via Shortcuts
    static func triggerGesture(_ type: GestureType) async {
        // Notify Shortcuts that this gesture occurred
        // This would be picked up by any automation listening for it
        print("Triggering Shortcuts for: \(type.rawValue)")
        
        // Post notification for Shortcuts to pick up
        let notificationName = "com.edgeless.clapper.\(type.rawValue)"
        NotificationCenter.default.post(
            name: Notification.Name(notificationName),
            object: nil
        )
    }
}
