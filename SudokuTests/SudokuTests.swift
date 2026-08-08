import XCTest
@testable import Sudoku

final class SudokuTests: XCTestCase {

    func testSolverCompletesValidBoard() {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        // Known partial board (row 0)
        let clues = [(0,0,5),(0,1,3),(0,4,7),(1,0,6),(1,3,1),(1,4,9),(1,5,5),
                     (2,1,9),(2,2,8),(2,7,6),(3,0,8),(3,4,6),(3,8,3),(4,0,4),
                     (4,3,8),(4,5,3),(4,8,1),(5,0,7),(5,4,2),(5,8,6),(6,1,6),
                     (6,6,2),(6,7,8),(7,3,4),(7,4,1),(7,5,9),(7,8,5),(8,4,8),(8,7,7),(8,8,9)]
        for (r,c,v) in clues { grid[r][c] = v }

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

    func testUniquenessAllDifficulties() {
        for difficulty in Difficulty.allCases {
            let board = PuzzleGenerator.generate(difficulty: difficulty)
            let puzzle = board.cells.map { row in row.map { $0.value ?? 0 } }
            let count = SudokuSolver.countSolutions(grid: puzzle, limit: 2)
            XCTAssertEqual(count, 1, "Expected unique solution for \(difficulty)")
        }
    }

    func testPencilMarkToggle() async {
        let vm = await GameViewModel(difficulty: .easy)
        await vm.startGame()
        // Find first non-given cell
        var targetRow = 0, targetCol = 0
        outer: for r in 0..<9 {
            for c in 0..<9 {
                let cell = await vm.board[r, c]
                if !cell.isGiven { targetRow = r; targetCol = c; break outer }
            }
        }
        await vm.selectCell(row: targetRow, col: targetCol)
        await vm.togglePencilMode()
        await vm.enterValue(5)
        let marksAfterFirst = await vm.board[targetRow, targetCol].pencilMarks
        XCTAssertTrue(marksAfterFirst.contains(5))
        let valueAfterFirst = await vm.board[targetRow, targetCol].value
        XCTAssertNil(valueAfterFirst)
        await vm.enterValue(5)
        let marksAfterSecond = await vm.board[targetRow, targetCol].pencilMarks
        XCTAssertFalse(marksAfterSecond.contains(5))
    }

    func testHintRevealsCorrectCell() async {
        let vm = await GameViewModel(difficulty: .easy)
        await vm.startGame()
        let initial = await vm.gameState.hintsRemaining

        // Hint no longer depends on selection — it picks the next logical cell.
        await vm.useHint()

        let after = await vm.gameState.hintsRemaining
        XCTAssertEqual(after, initial - 1)

        // The cell the hint chose is now selected and must hold the solution value.
        let row = await vm.gameState.selectedRow
        let col = await vm.gameState.selectedCol
        XCTAssertNotNil(row)
        XCTAssertNotNil(col)
        let solutionVal = await vm.board.solution[row!][col!]
        let cellVal = await vm.board[row!, col!].value
        XCTAssertEqual(cellVal, solutionVal)
        let isHint = await vm.board[row!, col!].isHint
        XCTAssertTrue(isHint)
    }
}
