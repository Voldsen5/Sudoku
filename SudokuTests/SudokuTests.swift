import XCTest
@testable import Sudoku

@MainActor
final class SudokuTests: XCTestCase {

    /// The classic puzzle from Wikipedia's Sudoku article.
    private let classicClues = [(0,0,5),(0,1,3),(0,4,7),(1,0,6),(1,3,1),(1,4,9),(1,5,5),
                                (2,1,9),(2,2,8),(2,7,6),(3,0,8),(3,4,6),(3,8,3),(4,0,4),
                                (4,3,8),(4,5,3),(4,8,1),(5,0,7),(5,4,2),(5,8,6),(6,1,6),
                                (6,6,2),(6,7,8),(7,3,4),(7,4,1),(7,5,9),(7,8,5),(8,4,8),(8,7,7),(8,8,9)]

    private nonisolated static let suiteName = "SudokuTests"

    override func setUp() {
        super.setUp()
        // Keep tests away from the real saved game and stats.
        let testDefaults = UserDefaults(suiteName: Self.suiteName)!
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        GamePersistence.defaults = testDefaults
        StatsStore.defaults = testDefaults
    }

    override func tearDown() {
        UserDefaults(suiteName: Self.suiteName)!.removePersistentDomain(forName: Self.suiteName)
        GamePersistence.defaults = .standard
        StatsStore.defaults = .standard
        super.tearDown()
    }

    // MARK: - Helpers

    private func newGame(_ difficulty: Difficulty = .easy) async -> GameViewModel {
        let vm = GameViewModel(difficulty: difficulty)
        await vm.startGame()
        return vm
    }

    private func emptyCells(_ vm: GameViewModel) -> [(Int, Int)] {
        (0..<81).map { ($0 / 9, $0 % 9) }.filter { vm.board[$0.0, $0.1].value == nil }
    }

    private func wrongDigit(_ vm: GameViewModel, _ r: Int, _ c: Int) -> Int {
        vm.board.solution[r][c] % 9 + 1
    }

    // MARK: - Solvers and generation

    func testSolverCompletesValidBoard() {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for (r, c, v) in classicClues { grid[r][c] = v }

        let result = SudokuSolver.solve(grid: &grid)
        XCTAssertTrue(result)
        for row in grid { for v in row { XCTAssertNotEqual(v, 0) } }
    }

    func testSolverRejectsUnsolvableBoard() {
        // Valid givens, but no completion exists: cell (0,8) needs 9 (row 0 holds
        // 1–8), yet column 8 already contains a 9 at (1,8) → no candidate.
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for c in 0..<8 { grid[0][c] = c + 1 } // row 0: 1...8
        grid[1][8] = 9
        let result = SudokuSolver.solve(grid: &grid)
        XCTAssertFalse(result)
    }

    func testLogicSolverGradesClassicPuzzleAsSingles() {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for (r, c, v) in classicClues { grid[r][c] = v }
        XCTAssertEqual(LogicSolver.grade(grid), .singles)
    }

    func testGeneratedPuzzlesAreUniqueAndMatchDifficulty() {
        for difficulty in Difficulty.allCases {
            for _ in 0..<3 {
                let board = PuzzleGenerator.generate(difficulty: difficulty)
                let puzzle = board.cells.map { row in row.map { $0.value ?? 0 } }
                XCTAssertEqual(SudokuSolver.countSolutions(grid: puzzle, limit: 2), 1,
                               "Expected unique solution for \(difficulty)")
                XCTAssertEqual(LogicSolver.grade(puzzle), difficulty.targetLevel,
                               "Wrong technique level for \(difficulty)")
            }
        }
    }

    // MARK: - Gameplay

    func testPencilMarkToggle() async {
        let vm = await newGame()
        let (r, c) = emptyCells(vm)[0]
        vm.selectCell(row: r, col: c)
        vm.togglePencilMode()
        vm.enterValue(5)
        XCTAssertTrue(vm.board[r, c].pencilMarks.contains(5))
        XCTAssertNil(vm.board[r, c].value)
        vm.enterValue(5)
        XCTAssertFalse(vm.board[r, c].pencilMarks.contains(5))
    }

    func testWrongEntriesCostLivesAndThirdMistakeLoses() async {
        let vm = await newGame()
        let cells = emptyCells(vm)
        for (i, (r, c)) in cells.prefix(3).enumerated() {
            vm.selectCell(row: r, col: c)
            vm.enterValue(wrongDigit(vm, r, c))
            XCTAssertEqual(vm.gameState.mistakeCount, i + 1)
            XCTAssertTrue(vm.board[r, c].isWrong)
        }
        XCTAssertEqual(vm.gameState.status, .lost)
    }

    func testRepeatingSameWrongDigitCostsOnlyOneLife() async {
        let vm = await newGame()
        let (r, c) = emptyCells(vm)[0]
        vm.selectCell(row: r, col: c)
        vm.enterValue(wrongDigit(vm, r, c))
        vm.enterValue(wrongDigit(vm, r, c))
        XCTAssertEqual(vm.gameState.mistakeCount, 1)
    }

    func testUndoRestoresBoardButNotLives() async {
        let vm = await newGame()
        let (r, c) = emptyCells(vm)[0]
        vm.selectCell(row: r, col: c)
        vm.enterValue(wrongDigit(vm, r, c))
        vm.undo()
        XCTAssertNil(vm.board[r, c].value)
        XCTAssertEqual(vm.gameState.mistakeCount, 1)
        XCTAssertFalse(vm.canUndo)
    }

    func testFillingTheSolutionWinsAndRecordsStats() async {
        let vm = await newGame()
        for (r, c) in emptyCells(vm) {
            vm.selectCell(row: r, col: c)
            vm.enterValue(vm.board.solution[r][c])
        }
        XCTAssertEqual(vm.gameState.status, .won)
        XCTAssertEqual(StatsStore.load().totalWins, 1)
        XCTAssertNil(GamePersistence.load(), "A finished game must not stay resumable")
    }

    // MARK: - Hints and notes

    func testHintRevealsDeducibleCellAndExplainsWhy() async {
        let vm = await newGame()
        let initial = vm.gameState.hintsRemaining

        vm.useHint()

        XCTAssertEqual(vm.gameState.hintsRemaining, initial - 1)
        let row = try! XCTUnwrap(vm.gameState.selectedRow)
        let col = try! XCTUnwrap(vm.gameState.selectedCol)
        XCTAssertEqual(vm.board[row, col].value, vm.board.solution[row][col])
        XCTAssertTrue(vm.board[row, col].isHint)
        // Easy puzzles are always solvable with singles, so there's always a reason.
        let message = try! XCTUnwrap(vm.hintMessage)
        XCTAssertFalse(message.contains("no single-step deduction"))
    }

    func testHintFlagsNotesThatRuleOutTheAnswer() async {
        let vm = await newGame()
        let (r, c) = emptyCells(vm)[0]
        vm.selectCell(row: r, col: c)
        vm.togglePencilMode()
        vm.enterValue(wrongDigit(vm, r, c))
        vm.selectCell(row: 0, col: 0)

        vm.useHint()

        XCTAssertEqual(vm.gameState.selectedRow, r)
        XCTAssertEqual(vm.gameState.selectedCol, c)
        XCTAssertNil(vm.board[r, c].value, "Flagging notes must not reveal the answer")
        XCTAssertNotNil(vm.hintMessage)
    }

    func testRemainingCountIgnoresWrongEntries() async {
        let vm = await newGame()
        let (r, c) = emptyCells(vm)[0]
        let answer = vm.board.solution[r][c]
        let before = vm.remainingCount(of: answer)

        let wrong = wrongDigit(vm, r, c)
        let wrongBefore = vm.remainingCount(of: wrong)
        vm.selectCell(row: r, col: c)
        vm.enterValue(wrong)
        XCTAssertEqual(vm.remainingCount(of: wrong), wrongBefore)

        vm.enterValue(answer)
        XCTAssertEqual(vm.remainingCount(of: answer), before - 1)
    }

    // MARK: - Persistence, stats, lifecycle

    func testSaveAndResumeRoundTrip() async throws {
        let vm = await newGame(.medium)
        let (r, c) = emptyCells(vm)[0]
        vm.selectCell(row: r, col: c)
        vm.enterValue(wrongDigit(vm, r, c))
        let (nr, nc) = emptyCells(vm)[0]
        vm.selectCell(row: nr, col: nc)
        vm.togglePencilMode()
        vm.enterValue(3)
        vm.persist()

        let saved = try XCTUnwrap(GamePersistence.load())
        let resumed = GameViewModel(difficulty: .easy)
        resumed.resumeGame(from: saved)

        XCTAssertEqual(resumed.board.cells, vm.board.cells)
        XCTAssertEqual(resumed.board.solution, vm.board.solution)
        XCTAssertEqual(resumed.gameState.difficulty, .medium)
        XCTAssertEqual(resumed.gameState.mistakeCount, 1)
        XCTAssertTrue(resumed.board[r, c].isWrong)
    }

    func testAbandoningSavedGameEndsStreak() {
        StatsStore.recordWin(difficulty: .easy, seconds: 100)
        StatsStore.recordWin(difficulty: .easy, seconds: 90)
        XCTAssertEqual(StatsStore.load().currentStreak, 2)

        GamePersistence.abandon()

        let stats = StatsStore.load()
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.bestStreak, 2)
        XCTAssertNil(GamePersistence.load())
    }

    func testBestTimeOnlyImproves() {
        XCTAssertTrue(StatsStore.recordWin(difficulty: .hard, seconds: 300))
        XCTAssertFalse(StatsStore.recordWin(difficulty: .hard, seconds: 400))
        XCTAssertTrue(StatsStore.recordWin(difficulty: .hard, seconds: 200))
        XCTAssertEqual(StatsStore.bestSeconds(for: .hard), 200)
    }

    func testLeavingTheAppPausesTheGame() async {
        let vm = await newGame()
        vm.pauseIfPlaying()
        XCTAssertEqual(vm.gameState.status, .paused)
        vm.pauseIfPlaying()
        XCTAssertEqual(vm.gameState.status, .paused, "Must not toggle back to playing")
    }
}
