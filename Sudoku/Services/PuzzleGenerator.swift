import Foundation

enum PuzzleGenerator {

    static func generate(difficulty: Difficulty) -> Board {
        // Build a complete, valid solution from a randomly-seeded set of diagonal
        // boxes (which are independent, so no validity check is needed).
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for box in 0..<3 {
            let digits = (1...9).shuffled()
            let start = box * 3
            var idx = 0
            for r in start..<start+3 {
                for c in start..<start+3 {
                    grid[r][c] = digits[idx]
                    idx += 1
                }
            }
        }
        SudokuSolver.solve(grid: &grid)
        let solution = grid

        // Remove cells while the puzzle stays uniquely solvable. Bounded by a
        // deadline so generation can never hang: if time runs out we simply keep
        // the remaining clues (a slightly easier puzzle) instead of retrying
        // forever. The result is always a valid, unique puzzle.
        let deadline = Date().addingTimeInterval(5)
        let positions = (0..<81).map { ($0 / 9, $0 % 9) }.shuffled()
        var cluesRemaining = 81

        for (row, col) in positions {
            if cluesRemaining <= difficulty.clueCount || Date() > deadline { break }
            let backup = grid[row][col]
            grid[row][col] = 0
            if SudokuSolver.countSolutions(grid: grid, limit: 2) == 1 {
                cluesRemaining -= 1
            } else {
                grid[row][col] = backup
            }
        }

        let cells: [[Cell]] = (0..<9).map { row in
            (0..<9).map { col in
                let v = grid[row][col]
                return Cell(value: v == 0 ? nil : v, isGiven: v != 0)
            }
        }
        return Board(cells: cells, solution: solution)
    }
}
