import Foundation

struct SavedGame: Codable {
    struct SavedCell: Codable {
        var value: Int?
        var pencilMarks: [Int]
        var isGiven: Bool
        var isHint: Bool
    }

    var cells: [[SavedCell]]
    var solution: [[Int]]
    var difficulty: String
    var elapsedSeconds: Int
    var hintsRemaining: Int
    var mistakeCount: Int
    var savedAt: Date
}

enum GamePersistence {
    /// Overridable so tests can use an isolated suite instead of the real store.
    nonisolated(unsafe) static var defaults = UserDefaults.standard
    private static let key = "savedGame"

    static func save(board: Board, state: GameState) {
        let saved = SavedGame(
            cells: board.cells.map { row in
                row.map { cell in
                    SavedGame.SavedCell(
                        value: cell.value,
                        pencilMarks: Array(cell.pencilMarks),
                        isGiven: cell.isGiven,
                        isHint: cell.isHint
                    )
                }
            },
            solution: board.solution,
            difficulty: state.difficulty.rawValue,
            elapsedSeconds: state.elapsedSeconds,
            hintsRemaining: state.hintsRemaining,
            mistakeCount: state.mistakeCount,
            savedAt: Date()
        )
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: key)
        }
    }

    static func load() -> SavedGame? {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data) else { return nil }
        return saved
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }

    /// Discards the saved game and counts it as a loss, so a win streak can't be
    /// protected by abandoning a run before the third mistake.
    static func abandon() {
        clear()
        StatsStore.recordLoss()
    }

    static func restore(from saved: SavedGame) -> (Board, GameState)? {
        guard let difficulty = Difficulty(rawValue: saved.difficulty) else { return nil }

        let cells: [[Cell]] = saved.cells.enumerated().map { r, row in
            row.enumerated().map { c, sc in
                var cell = Cell(value: sc.value, isGiven: sc.isGiven)
                cell.pencilMarks = Set(sc.pencilMarks)
                cell.isHint = sc.isHint
                if let v = sc.value, !sc.isGiven, v != saved.solution[r][c] {
                    cell.isWrong = true
                }
                return cell
            }
        }
        let board = Board(cells: cells, solution: saved.solution)

        var state = GameState()
        state.difficulty = difficulty
        state.elapsedSeconds = saved.elapsedSeconds
        state.hintsRemaining = saved.hintsRemaining
        state.mistakeCount = saved.mistakeCount
        return (board, state)
    }
}
