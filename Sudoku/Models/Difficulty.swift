import Foundation

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard

    var id: String { rawValue }

    var clueCount: Int {
        switch self {
        case .easy:   return 38
        case .medium: return 30
        case .hard:   return 24
        }
    }

    var hintAllowance: Int {
        switch self {
        case .easy:   return 5
        case .medium: return 3
        case .hard:   return 1
        }
    }

    var displayName: String { rawValue.capitalized }

    var subtitle: String {
        switch self {
        case .easy:   return "\(clueCount) clues · \(hintAllowance) hints"
        case .medium: return "\(clueCount) clues · \(hintAllowance) hints"
        case .hard:   return "\(clueCount) clues · \(hintAllowance) hint"
        }
    }

    var badge: String {
        switch self {
        case .easy:   return "Relaxed"
        case .medium: return "Popular"
        case .hard:   return "Challenge"
        }
    }

    var badgeColor: String {
        switch self {
        case .easy:   return "green"
        case .medium: return "blue"
        case .hard:   return "red"
        }
    }
}
