import UIKit

/// Thin wrapper around UIKit's haptic generators so the rest of the app can
/// trigger feedback without importing UIKit everywhere.
@MainActor
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
