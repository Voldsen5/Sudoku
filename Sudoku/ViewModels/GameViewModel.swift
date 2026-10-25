import Foundation
import Observation

@MainActor
@Observable
final class GameViewModel {
    var board: Board
    var gameState: GameState
    var isLoading = false
    var isNewBestTime = false
    /// Why the last hint chose its cell. Cleared on the player's next action.
    var hintMessage: String?
    private(set) var isResumed = false

    @ObservationIgnored private var timerTask: Task<Void, Never>?
    private var history: [Board] = []

    var canUndo: Bool { !history.isEmpty && gameState.status == .playing }

    init(difficulty: Difficulty) {
        let empty = Board(
            cells: (0..<9).map { _ in (0..<9).map { _ in Cell() } },
            solution: Array(repeating: Array(repeating: 0, count: 9), count: 9)
        )
        self.board = empty
        self.gameState = GameState()
        self.gameState.difficulty = difficulty
        self.gameState.hintsRemaining = difficulty.hintAllowance
    }

    func startGame() async {
        isLoading = true
        stopTimer()

        let difficulty = gameState.difficulty
        let newBoard = await Task.detached(priority: .userInitiated) {
            PuzzleGenerator.generate(difficulty: difficulty)
        }.value

        board = newBoard
        gameState = GameState()
        gameState.difficulty = difficulty
        gameState.hintsRemaining = difficulty.hintAllowance
        history.removeAll()
        hintMessage = nil
        isLoading = false
        startTimer()
    }

    func resumeGame(from saved: SavedGame) {
        guard let (restoredBoard, restoredState) = GamePersistence.restore(from: saved) else { return }
        board = restoredBoard
        gameState = restoredState
        isResumed = true
    }

    func saveAndExit() {
        persist()
        stopTimer()
    }

    /// Saves the current game if it is still in progress. Safe to call repeatedly
    /// (e.g. when the app moves to the background) — does not touch the timer.
    func persist() {
        guard gameState.status == .playing || gameState.status == .paused else { return }
        GamePersistence.save(board: board, state: gameState)
    }

    func selectCell(row: Int, col: Int) {
        gameState.selectedRow = row
        gameState.selectedCol = col
        hintMessage = nil
    }

    func enterValue(_ digit: Int) {
        guard let row = gameState.selectedRow,
              let col = gameState.selectedCol,
              !board[row, col].isGiven,
              board[row, col].value != board.solution[row][col],
              gameState.status == .playing else { return }
        hintMessage = nil

        if gameState.isPencilMode {
            snapshot()
            if board[row, col].pencilMarks.contains(digit) {
                board[row, col].pencilMarks.remove(digit)
            } else {
                board[row, col].pencilMarks.insert(digit)
            }
            Haptics.tap()
        } else {
            // Ignore re-tapping the digit already in the cell (e.g. an accidental
            // double tap on a wrong guess) so it can't cost a second heart.
            guard board[row, col].value != digit else { return }

            snapshot()
            let correct = board.solution[row][col]
            board[row, col].value = digit
            board[row, col].pencilMarks = []

            if digit == correct {
                board[row, col].isWrong = false
                clearWrongEntries()
                eliminatePencilMark(digit, fromPeersOf: row, col: col)
                Haptics.tap()
                checkWin()
            } else {
                board[row, col].isWrong = true
                gameState.mistakeCount += 1
                if gameState.mistakeCount >= GameState.maxMistakes {
                    gameState.status = .lost
                    StatsStore.recordLoss()
                    GamePersistence.clear()
                    stopTimer()
                }
                Haptics.error()
            }
        }
    }

    func erase() {
        guard let row = gameState.selectedRow,
              let col = gameState.selectedCol,
              !board[row, col].isGiven,
              board[row, col].value != board.solution[row][col],
              gameState.status == .playing else { return }
        guard board[row, col].value != nil || !board[row, col].pencilMarks.isEmpty else { return }
        snapshot()
        hintMessage = nil
        board[row, col].value = nil
        board[row, col].pencilMarks = []
        board[row, col].isWrong = false
        Haptics.tap()
    }

    func togglePencilMode() {
        gameState.isPencilMode.toggle()
    }

    /// How many more of `digit` the player still has to place correctly.
    func remainingCount(of digit: Int) -> Int {
        var placed = 0
        for r in 0..<9 {
            for c in 0..<9 where board[r, c].value == digit && !board[r, c].isWrong {
                placed += 1
            }
        }
        return 9 - placed
    }

    /// Reveals the next cell the player could logically deduce and explains why.
    /// If the player's notes rule out a cell's real answer, points that out first:
    /// those notes would otherwise lead them astray.
    func useHint() {
        guard gameState.hintsRemaining > 0, gameState.status == .playing else { return }

        if let (row, col) = cellWithBrokenNotes() {
            gameState.hintsRemaining -= 1
            gameState.selectedRow = row
            gameState.selectedCol = col
            hintMessage = "Your notes here rule out the correct number. Take another look."
            Haptics.tap()
            return
        }

        let grid = confirmedGrid
        let row: Int, col: Int, message: String
        if let step = LogicSolver.nextDeduction(in: grid) {
            (row, col) = (step.row, step.col)
            message = explanation(for: step)
        } else if let cell = mostConstrainedEmptyCell(in: grid) {
            (row, col) = cell
            message = "There's no single-step deduction right now, so here's a cell to get you moving."
        } else {
            return
        }

        snapshot()
        let correct = board.solution[row][col]
        board[row, col].value = correct
        board[row, col].pencilMarks = []
        board[row, col].isGiven = true
        board[row, col].isHint = true
        board[row, col].isWrong = false
        gameState.hintsRemaining -= 1
        clearWrongEntries()
        eliminatePencilMark(correct, fromPeersOf: row, col: col)
        // Move the selection to the revealed cell so the user can see it.
        gameState.selectedRow = row
        gameState.selectedCol = col
        hintMessage = message
        Haptics.tap()
        checkWin()
    }

    func undo() {
        guard gameState.status == .playing, let previous = history.popLast() else { return }
        board = previous
        hintMessage = nil
        Haptics.tap()
    }

    func togglePause() {
        switch gameState.status {
        case .playing:
            gameState.status = .paused
        case .paused:
            gameState.status = .playing
        default:
            break
        }
    }

    /// Pauses when the app stops being active (Control Center, a call, the app
    /// switcher) so the clock never runs while the player can't see the board.
    func pauseIfPlaying() {
        if gameState.status == .playing { gameState.status = .paused }
    }

    // MARK: - Private

    /// Saves the current board so the move about to happen can be undone. Bounded
    /// so a very long game can't grow the history without limit.
    private func snapshot() {
        history.append(board)
        if history.count > 60 { history.removeFirst() }
    }

    /// The board as the player has correctly filled it (0 = empty). Wrong guesses
    /// count as empty so they don't corrupt candidate logic.
    private var confirmedGrid: [[Int]] {
        board.cells.map { row in row.map { $0.isWrong ? 0 : ($0.value ?? 0) } }
    }

    private func cellWithBrokenNotes() -> (Int, Int)? {
        for r in 0..<9 {
            for c in 0..<9 {
                let cell = board[r, c]
                if cell.value == nil, !cell.pencilMarks.isEmpty,
                   !cell.pencilMarks.contains(board.solution[r][c]) {
                    return (r, c)
                }
            }
        }
        return nil
    }

    private func mostConstrainedEmptyCell(in grid: [[Int]]) -> (Int, Int)? {
        let candidates = LogicSolver.candidates(in: grid)
        var best: (row: Int, col: Int, count: Int)?
        for r in 0..<9 {
            for c in 0..<9 where grid[r][c] == 0 {
                let count = candidates[r][c].nonzeroBitCount
                if best == nil || count < best!.count { best = (r, c, count) }
            }
        }
        return best.map { ($0.row, $0.col) }
    }

    private func explanation(for step: LogicSolver.Deduction) -> String {
        switch step.reason {
        case .nakedSingle:
            return "Only \(step.digit) fits here. Every other number is already in this row, column or box."
        case .hiddenSingle(let unit):
            let place: String
            switch unit {
            case .row(let r):    place = "row \(r + 1)"
            case .column(let c): place = "column \(c + 1)"
            case .box:           place = "this box"
            }
            return "This is the only cell in \(place) where \(step.digit) can go."
        }
    }

    /// Removes every cell still flagged as a wrong guess, emptying it back out.
    /// Called after a correct entry so stale mistakes don't linger on the board.
    private func clearWrongEntries() {
        for r in 0..<9 {
            for c in 0..<9 where board[r, c].isWrong {
                board[r, c].value = nil
                board[r, c].isWrong = false
            }
        }
    }

    private func eliminatePencilMark(_ digit: Int, fromPeersOf row: Int, col: Int) {
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for i in 0..<9 {
            board[row, i].pencilMarks.remove(digit)
            board[i, col].pencilMarks.remove(digit)
        }
        for r in boxRow..<boxRow+3 {
            for c in boxCol..<boxCol+3 {
                board[r, c].pencilMarks.remove(digit)
            }
        }
    }

    private func checkWin() {
        if board.isSolved {
            gameState.status = .won
            isNewBestTime = StatsStore.recordWin(
                difficulty: gameState.difficulty,
                seconds: gameState.elapsedSeconds
            )
            GamePersistence.clear()
            Haptics.success()
            stopTimer()
        }
    }

    func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if self.gameState.status == .playing {
                    self.gameState.elapsedSeconds += 1
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
