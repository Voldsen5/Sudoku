import Foundation

struct Cell: Identifiable, Equatable {
    let id: UUID
    var value: Int?
    var pencilMarks: Set<Int>
    var isGiven: Bool
    var isHint: Bool
    var isSelected: Bool
    var isHighlighted: Bool
    var isWrong: Bool
    var isSameValue: Bool

    init(value: Int? = nil, isGiven: Bool = false) {
        self.id = UUID()
        self.value = value
        self.pencilMarks = []
        self.isGiven = isGiven
        self.isHint = false
        self.isSelected = false
        self.isHighlighted = false
        self.isWrong = false
        self.isSameValue = false
    }
}
