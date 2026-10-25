import Foundation

enum PuzzleGenerator {

    /// Generates a uniquely solvable puzzle whose hardest required technique
    /// matches the difficulty. Tries fresh puzzles until one grades correctly;
    /// bounded by a deadline so generation can never hang — worst case it returns
    /// the closest match found, which is still a valid, unique puzzle.
    static func generate(difficulty: Difficulty) -> Board {
        let deadline = Date().addingTimeInterval(3)
        var best: (puzzle: [[Int]], solution: [[Int]], distance: Int)?

        repeat {
            let solution = randomSolution()
            let puzzle = carve(solution, difficulty: difficulty)
            let distance = abs(LogicSolver.grade(puzzle).rawValue - difficulty.targetLevel.rawValue)
            if distance == 0 { return makeBoard(puzzle: puzzle, solution: solution) }
            if best == nil || distance < best!.distance {
                best = (puzzle, solution, distance)
            }
        } while Date() < deadline

        return makeBoard(puzzle: best!.puzzle, solution: best!.solution)
    }

    /// A complete, valid grid. The diagonal boxes are independent, so they can be
    /// filled at random without checks; the solver completes the rest, and a
    /// random digit relabelling adds variety to what the solver fills in.
    private static func randomSolution() -> [[Int]] {
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
        let relabel = [0] + (1...9).shuffled()
        return grid.map { row in row.map { relabel[$0] } }
    }

    /// Removes clues in random order while the puzzle stays uniquely solvable and
    /// no harder than the difficulty allows.
    private static func carve(_ solution: [[Int]], difficulty: Difficulty) -> [[Int]] {
        var grid = solution
        var cluesRemaining = 81
        for i in (0..<81).shuffled() {
            if cluesRemaining <= difficulty.minimumClues { break }
            let (row, col) = (i / 9, i % 9)
            let backup = grid[row][col]
            grid[row][col] = 0
            if SudokuSolver.countSolutions(grid: grid, limit: 2) == 1,
               LogicSolver.grade(grid) <= difficulty.targetLevel {
                cluesRemaining -= 1
            } else {
                grid[row][col] = backup
            }
        }
        return grid
    }

    private static func makeBoard(puzzle: [[Int]], solution: [[Int]]) -> Board {
        let cells: [[Cell]] = puzzle.map { row in
            row.map { v in Cell(value: v == 0 ? nil : v, isGiven: v != 0) }
        }
        return Board(cells: cells, solution: solution)
    }
}
