import Foundation

/// Supported gesture types for audio pattern detection
enum GestureType: String, Codable, CaseIterable, Identifiable {
    case singleClap
    case doubleClap
    case tripleClap
    case singleSnap
    case doubleSnap
    case custom
    
    var id: String { rawValue }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .singleClap: return "Single Clap"
        case .doubleClap: return "Double Clap"
        case .tripleClap: return "Triple Clap"
        case .singleSnap: return "Single Snap"
        case .doubleSnap: return "Double Snap"
        case .custom: return "Custom Gesture"
        }
    }
    
    /// Icon name for UI
    var iconName: String {
        switch self {
        case .singleClap, .doubleClap, .tripleClap:
            return "hand.tap.fill"
        case .singleSnap, .doubleSnap:
            return "sparkles"
        case .custom:
            return "star.fill"
        }
    }
    
    /// Peak count required for this gesture
    var peakCount: Int {
        switch self {
        case .singleClap, .singleSnap: return 1
        case .doubleClap, .doubleSnap: return 2
        case .tripleClap: return 3
        case .custom: return 0 // Variable
        }
    }
    
    /// Is this a built-in gesture (not custom)
    var isBuiltIn: Bool {
        self != .custom
    }
    
    /// Description for Shortcuts integration
    var shortcutsDescription: String {
        "When \(displayName.lowercased()) is detected"
    }
}

// MARK: - Peak Types

/// Types of detected audio peaks
enum PeakType: String, Codable {
    case clap
    case snap
    case custom
    
    var frequencyRange: ClosedRange<Float> {
        switch self {
        case .clap:
            return 2000...5000  // 2-5kHz
        case .snap:
            return 5000...8000  // 5-8kHz
        case .custom:
            return 1000...10000 // Full range
        }
    }
}

// MARK: - Intent Dispatcher

/// Dispatches gesture detection to iOS Shortcuts via App Intents
class IntentDispatcher {
    static let shared = IntentDispatcher()
    
    private init() {}
    
    /// Dispatch a gesture intent to Shortcuts
    func dispatchGestureIntent(_ gesture: GestureType) {
        // In real implementation, this would:
        // 1. Create an NSUserActivity with gesture info
        // 2. Post notification for Shortcuts to pick up
        // 3. Or use App Intents directly if app is active
        
        print("Dispatching intent for: \(gesture.displayName)")
        
        // Post notification that Shortcuts can listen for
        NotificationCenter.default.post(
            name: .gestureIntentTriggered,
            object: nil,
            userInfo: ["gestureType": gesture.rawValue]
        )
    }
}

extension Notification.Name {
    static let gestureIntentTriggered = Notification.Name("gestureIntentTriggered")
}
