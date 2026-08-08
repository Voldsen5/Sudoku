import Foundation

struct Board {
    var cells: [[Cell]]
    var solution: [[Int]]

    init(cells: [[Cell]], solution: [[Int]]) {
        self.cells = cells
        self.solution = solution
    }

    subscript(row: Int, col: Int) -> Cell {
        get { cells[row][col] }
        set { cells[row][col] = newValue }
    }

    /// True only when every cell matches the solution exactly.
    var isSolved: Bool {
        for r in 0..<9 {
            for c in 0..<9 {
                if cells[r][c].value != solution[r][c] { return false }
            }
        }
        return true
    }
}
