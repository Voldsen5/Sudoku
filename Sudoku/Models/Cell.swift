import Foundation

/// Game data for one square. Selection and highlighting are derived by the
/// view from the current selection, so they don't live here.
struct Cell: Equatable {
    var value: Int?
    var pencilMarks: Set<Int>
    var isGiven: Bool
    var isHint: Bool
    var isWrong: Bool

    init(value: Int? = nil, isGiven: Bool = false) {
        self.value = value
        self.pencilMarks = []
        self.isGiven = isGiven
        self.isHint = false
        self.isWrong = false
    }
}
