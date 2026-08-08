import Foundation

enum SudokuSolver {

    // Bitmask of used values per row, col, box (1-indexed → bit 1..9)
    private struct Masks {
        var rows = [Int](repeating: 0, count: 9)
        var cols = [Int](repeating: 0, count: 9)
        var boxes = [Int](repeating: 0, count: 9)

        init(_ grid: [[Int]]) {
            for r in 0..<9 {
                for c in 0..<9 {
                    let v = grid[r][c]
                    if v != 0 { place(v, row: r, col: c) }
                }
            }
        }

        mutating func place(_ v: Int, row: Int, col: Int) {
            let bit = 1 << v
            rows[row] |= bit; cols[col] |= bit; boxes[box(row, col)] |= bit
        }

        mutating func remove(_ v: Int, row: Int, col: Int) {
            let bit = 1 << v
            rows[row] &= ~bit; cols[col] &= ~bit; boxes[box(row, col)] &= ~bit
        }

        func candidates(row: Int, col: Int) -> Int {
            // bits 1-9 that are NOT used in row, col, or box
            let used = rows[row] | cols[col] | boxes[box(row, col)]
            return (~used) & 0b1111111110  // bits 1..9
        }

        func box(_ r: Int, _ c: Int) -> Int { (r / 3) * 3 + c / 3 }
    }

    @discardableResult
    static func solve(grid: inout [[Int]]) -> Bool {
        var masks = Masks(grid)
        return solveHelper(&grid, masks: &masks)
    }

    private static func solveHelper(_ grid: inout [[Int]], masks: inout Masks) -> Bool {
        // Find the empty cell with the fewest candidates (MRV heuristic)
        var bestRow = -1, bestCol = -1, bestCount = 10
        for r in 0..<9 {
            for c in 0..<9 {
                guard grid[r][c] == 0 else { continue }
                let count = grid[r][c] == 0 ? masks.candidates(row: r, col: c).nonzeroBitCount : 99
                if count < bestCount {
                    bestCount = count; bestRow = r; bestCol = c
                    if count == 0 { return false }
                }
            }
        }
        if bestRow == -1 { return true }  // all filled

        var bits = masks.candidates(row: bestRow, col: bestCol)
        while bits != 0 {
            let bit = bits & (-bits)      // lowest set bit
            bits &= bits - 1
            let num = bit.trailingZeroBitCount
            grid[bestRow][bestCol] = num
            masks.place(num, row: bestRow, col: bestCol)
            if solveHelper(&grid, masks: &masks) { return true }
            masks.remove(num, row: bestRow, col: bestCol)
            grid[bestRow][bestCol] = 0
        }
        return false
    }

    static func countSolutions(grid: [[Int]], limit: Int) -> Int {
        var grid = grid
        var masks = Masks(grid)
        var count = 0
        countHelper(&grid, masks: &masks, count: &count, limit: limit)
        return count
    }

    private static func countHelper(_ grid: inout [[Int]], masks: inout Masks, count: inout Int, limit: Int) {
        guard count < limit else { return }

        var bestRow = -1, bestCol = -1, bestCount = 10
        for r in 0..<9 {
            for c in 0..<9 {
                guard grid[r][c] == 0 else { continue }
                let n = masks.candidates(row: r, col: c).nonzeroBitCount
                if n < bestCount {
                    bestCount = n; bestRow = r; bestCol = c
                    if n == 0 { return }
                }
            }
        }
        if bestRow == -1 { count += 1; return }

        var bits = masks.candidates(row: bestRow, col: bestCol)
        while bits != 0 && count < limit {
            let bit = bits & (-bits)
            bits &= bits - 1
            let num = bit.trailingZeroBitCount
            grid[bestRow][bestCol] = num
            masks.place(num, row: bestRow, col: bestCol)
            countHelper(&grid, masks: &masks, count: &count, limit: limit)
            masks.remove(num, row: bestRow, col: bestCol)
            grid[bestRow][bestCol] = 0
        }
    }
}
