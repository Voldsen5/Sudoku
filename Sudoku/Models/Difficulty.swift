import Foundation

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard

    var id: String { rawValue }

    /// The hardest solving technique a puzzle of this difficulty needs.
    var targetLevel: LogicSolver.Level {
        switch self {
        case .easy:   return .singles
        case .medium: return .intermediate
        case .hard:   return .advanced
        }
    }

    /// The generator stops removing clues at this count. Easy keeps plenty of
    /// clues so it stays relaxed; medium and hard carve as far as uniqueness allows.
    var minimumClues: Int {
        switch self {
        case .easy:   return 36
        case .medium: return 24
        case .hard:   return 17
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
        let technique: String
        switch self {
        case .easy:   technique = "Singles only"
        case .medium: technique = "Pairs & pointing"
        case .hard:   technique = "Advanced logic"
        }
        return "\(technique) · \(hintAllowance) \(hintAllowance == 1 ? "hint" : "hints")"
    }

    var badge: String {
        switch self {
        case .easy:   return "Relaxed"
        case .medium: return "Popular"
        case .hard:   return "Challenge"
        }
    }
}
