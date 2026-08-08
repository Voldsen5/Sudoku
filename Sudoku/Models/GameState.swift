import Foundation

enum GameStatus {
    case playing, paused, won, lost
}

struct GameState {
    var status: GameStatus = .playing
    var hintsRemaining: Int = 3
    var elapsedSeconds: Int = 0
    var isPencilMode: Bool = false
    var selectedRow: Int? = nil
    var selectedCol: Int? = nil
    var difficulty: Difficulty = .medium
    var mistakeCount: Int = 0
    static let maxMistakes = 3
}
