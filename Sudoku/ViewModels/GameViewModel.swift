import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    @Published var board: Board
    @Published var gameState: GameState
    @Published var isLoading: Bool = false
    @Published var isNewBestTime: Bool = false
    private(set) var isResumed: Bool = false

    private var timerCancellable: AnyCancellable?
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
        updateHighlights()
    }

    func enterValue(_ digit: Int) {
        guard let row = gameState.selectedRow,
              let col = gameState.selectedCol,
              !board[row, col].isGiven,
              board[row, col].value != board.solution[row][col],
              gameState.status == .playing else { return }

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
                updateHighlights()
                Haptics.tap()
                checkWin()
            } else {
                board[row, col].isWrong = true
                updateHighlights()
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
        board[row, col].value = nil
        board[row, col].pencilMarks = []
        board[row, col].isWrong = false
        updateHighlights()
        Haptics.tap()
    }

    func togglePencilMode() {
        gameState.isPencilMode.toggle()
    }

    func useHint() {
        guard gameState.hintsRemaining > 0,
              gameState.status == .playing,
              let (row, col) = findHintCell() else { return }

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
        updateHighlights()
        Haptics.tap()
        checkWin()
    }

    func undo() {
        guard gameState.status == .playing, let previous = history.popLast() else { return }
        board = previous
        updateHighlights()
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

    // MARK: - Private

    /// Saves the current board so the move about to happen can be undone. Bounded
    /// so a very long game can't grow the history without limit.
    private func snapshot() {
        history.append(board)
        if history.count > 60 { history.removeFirst() }
    }

    /// Picks the best cell for a hint: the next cell the player could logically
    /// deduce. Prefers a "naked single" (an empty cell with exactly one possible
    /// value); otherwise falls back to the most-constrained empty cell. Wrong
    /// guesses are treated as empty so they don't corrupt the candidate logic.
    private func findHintCell() -> (Int, Int)? {
        func confirmedValue(_ r: Int, _ c: Int) -> Int? {
            let cell = board[r, c]
            if let v = cell.value, !cell.isWrong { return v }
            return nil
        }

        func candidateCount(_ r: Int, _ c: Int) -> Int {
            var used = Set<Int>()
            let boxRow = (r / 3) * 3
            let boxCol = (c / 3) * 3
            for i in 0..<9 {
                if let v = confirmedValue(r, i) { used.insert(v) }
                if let v = confirmedValue(i, c) { used.insert(v) }
            }
            for rr in boxRow..<boxRow+3 {
                for cc in boxCol..<boxCol+3 {
                    if let v = confirmedValue(rr, cc) { used.insert(v) }
                }
            }
            return 9 - used.count
        }

        var best: (row: Int, col: Int, count: Int)? = nil
        for r in 0..<9 {
            for c in 0..<9 where confirmedValue(r, c) == nil {
                let count = candidateCount(r, c)
                if count == 1 { return (r, c) }          // naked single — ideal hint
                if best == nil || count < best!.count {
                    best = (r, c, count)
                }
            }
        }
        guard let best else { return nil }
        return (best.row, best.col)
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

    private func updateHighlights() {
        guard let selRow = gameState.selectedRow,
              let selCol = gameState.selectedCol else { return }
        let boxRow = (selRow / 3) * 3
        let boxCol = (selCol / 3) * 3
        let selectedValue = board[selRow, selCol].value
        for r in 0..<9 {
            for c in 0..<9 {
                let isSelected = r == selRow && c == selCol
                board[r, c].isSelected = isSelected
                board[r, c].isHighlighted = (r == selRow || c == selCol ||
                    (r >= boxRow && r < boxRow+3 && c >= boxCol && c < boxCol+3))
                    && !isSelected
                board[r, c].isSameValue = !isSelected
                    && selectedValue != nil
                    && board[r, c].value == selectedValue
            }
        }
    }

    func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.gameState.status == .playing else { return }
                self.gameState.elapsedSeconds += 1
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
