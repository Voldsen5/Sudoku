import Foundation

/// Human-style solver used to grade puzzles and explain hints. Unlike
/// `SudokuSolver`, which brute-forces with backtracking, it only applies the
/// techniques a person would use — so how far it gets measures how hard a
/// puzzle actually *feels*, not just how many clues it has.
enum LogicSolver {

    /// The hardest family of techniques a puzzle needs.
    enum Level: Int, Comparable {
        /// Naked and hidden singles only.
        case singles = 1
        /// Also needs locked candidates (pointing / claiming) or naked / hidden pairs.
        case intermediate
        /// Can't be finished with the techniques above.
        case advanced

        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    enum Unit: Equatable {
        case row(Int), column(Int), box(Int)
    }

    /// A single placement a player could make next, and why it works.
    struct Deduction: Equatable {
        enum Reason: Equatable {
            /// Every other digit already appears in the cell's row, column or box.
            case nakedSingle
            /// The cell is the only place in the unit where the digit can go.
            case hiddenSingle(Unit)
        }
        let row: Int
        let col: Int
        let digit: Int
        let reason: Reason
    }

    /// Grades a puzzle (0 = empty) by the hardest technique needed to solve it.
    static func grade(_ grid: [[Int]]) -> Level {
        var state = State(grid)
        var level = Level.singles
        while !state.isSolved {
            if let step = state.nextSingle() {
                state.place(step.digit, at: step.row * 9 + step.col)
            } else if state.applyIntermediate() {
                level = .intermediate
            } else {
                return .advanced
            }
        }
        return level
    }

    /// The next naked or hidden single on the board, if there is one.
    static func nextDeduction(in grid: [[Int]]) -> Deduction? {
        State(grid).nextSingle()
    }

    /// Candidate digits for every cell, as bitmasks (bit n set = digit n fits).
    /// Filled cells have no candidates.
    static func candidates(in grid: [[Int]]) -> [[Int]] {
        let state = State(grid)
        return (0..<9).map { r in (0..<9).map { c in state.cands[r * 9 + c] } }
    }

    // MARK: - Geometry

    private static let units: [[Int]] =
        (0..<9).map { r in (0..<9).map { r * 9 + $0 } } +
        (0..<9).map { c in (0..<9).map { $0 * 9 + c } } +
        (0..<9).map { b in (0..<9).map { ((b / 3) * 3 + $0 / 3) * 9 + (b % 3) * 3 + $0 % 3 } }

    private static let unitKinds: [Unit] =
        (0..<9).map(Unit.row) + (0..<9).map(Unit.column) + (0..<9).map(Unit.box)

    private static let peers: [[Int]] = (0..<81).map { i in
        Array(Set(units.filter { $0.contains(i) }.joined()).subtracting([i]))
    }

    private static func box(of i: Int) -> Int { (i / 27) * 3 + (i % 9) / 3 }

    private static let allDigits = 0b11_1111_1110

    // MARK: - Solver state

    private struct State {
        var values: [Int]
        var cands: [Int]

        init(_ grid: [[Int]]) {
            values = grid.flatMap { $0 }
            cands = Array(repeating: 0, count: 81)
            for i in 0..<81 where values[i] == 0 {
                let used = peers[i].reduce(0) { $0 | (1 << values[$1]) }
                cands[i] = allDigits & ~used
            }
        }

        var isSolved: Bool { !values.contains(0) }

        mutating func place(_ digit: Int, at i: Int) {
            values[i] = digit
            cands[i] = 0
            for p in peers[i] { cands[p] &= ~(1 << digit) }
        }

        func nextSingle() -> Deduction? {
            for i in 0..<81 where values[i] == 0 && cands[i].nonzeroBitCount == 1 {
                return Deduction(row: i / 9, col: i % 9,
                                 digit: cands[i].trailingZeroBitCount, reason: .nakedSingle)
            }
            for (u, unit) in units.enumerated() {
                for digit in 1...9 {
                    let bit = 1 << digit
                    let spots = unit.filter { cands[$0] & bit != 0 }
                    if spots.count == 1 {
                        let i = spots[0]
                        return Deduction(row: i / 9, col: i % 9, digit: digit,
                                         reason: .hiddenSingle(unitKinds[u]))
                    }
                }
            }
            return nil
        }

        /// Applies one round of intermediate eliminations. Returns true if any
        /// candidate was removed.
        mutating func applyIntermediate() -> Bool {
            lockedCandidates() || nakedPairs() || hiddenPairs()
        }

        /// Pointing: a digit confined to one row/column within a box can be
        /// removed from the rest of that row/column. Claiming is the reverse.
        private mutating func lockedCandidates() -> Bool {
            var changed = false
            for (u, unit) in units.enumerated() {
                for digit in 1...9 {
                    let bit = 1 << digit
                    let spots = unit.filter { cands[$0] & bit != 0 }
                    guard spots.count >= 2 else { continue }
                    let targets: [Int]
                    if u >= 18 {
                        // Box: are all spots in one row or one column?
                        if Set(spots.map { $0 / 9 }).count == 1 {
                            targets = units[spots[0] / 9]
                        } else if Set(spots.map { $0 % 9 }).count == 1 {
                            targets = units[9 + spots[0] % 9]
                        } else { continue }
                    } else {
                        // Row / column: are all spots in one box?
                        guard Set(spots.map(box(of:))).count == 1 else { continue }
                        targets = units[18 + box(of: spots[0])]
                    }
                    for t in targets where !spots.contains(t) && cands[t] & bit != 0 {
                        cands[t] &= ~bit
                        changed = true
                    }
                }
            }
            return changed
        }

        /// Two cells in a unit sharing the same two candidates claim those
        /// digits; remove them from the rest of the unit.
        private mutating func nakedPairs() -> Bool {
            var changed = false
            for unit in units {
                let pairs = unit.filter { cands[$0].nonzeroBitCount == 2 }
                for (a, i) in pairs.enumerated() {
                    for j in pairs[(a + 1)...] where cands[i] == cands[j] {
                        let mask = cands[i]
                        for k in unit where k != i && k != j && cands[k] & mask != 0 {
                            cands[k] &= ~mask
                            changed = true
                        }
                    }
                }
            }
            return changed
        }

        /// Two digits that can only go in the same two cells of a unit: those
        /// cells can't hold anything else.
        private mutating func hiddenPairs() -> Bool {
            var changed = false
            for unit in units {
                var spotsByDigit: [Int: [Int]] = [:]
                for digit in 1...9 {
                    let spots = unit.filter { cands[$0] & (1 << digit) != 0 }
                    if spots.count == 2 { spotsByDigit[digit] = spots }
                }
                let digits = spotsByDigit.keys.sorted()
                for (a, d1) in digits.enumerated() {
                    for d2 in digits[(a + 1)...] where spotsByDigit[d1] == spotsByDigit[d2] {
                        let mask = (1 << d1) | (1 << d2)
                        for i in spotsByDigit[d1]! where cands[i] != mask {
                            cands[i] = mask
                            changed = true
                        }
                    }
                }
            }
            return changed
        }
    }
}
