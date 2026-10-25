import SwiftUI

struct CellView: View, Equatable {
    let cell: Cell
    let row: Int
    let col: Int
    let isSelected: Bool
    let isHighlighted: Bool
    let isSameValue: Bool
    let size: CGFloat
    let onTap: () -> Void

    /// Ignores `onTap` so SwiftUI can skip redrawing cells whose state is unchanged.
    nonisolated static func == (a: CellView, b: CellView) -> Bool {
        a.cell == b.cell && a.row == b.row && a.col == b.col
            && a.isSelected == b.isSelected && a.isHighlighted == b.isHighlighted
            && a.isSameValue == b.isSameValue && a.size == b.size
    }

    var body: some View {
        ZStack {
            Rectangle().fill(backgroundColor)
            content
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            // A shape cue as well as colour, so mistakes don't rely on seeing red.
            if cell.isWrong {
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(size * 0.06)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var content: some View {
        if let value = cell.value {
            Text("\(value)")
                .font(.system(size: size * 0.55, weight: cell.isGiven ? .bold : .regular))
                .foregroundStyle(digitColor)
        } else if !cell.pencilMarks.isEmpty {
            PencilMarksView(marks: cell.pencilMarks, fontSize: size * 0.26)
        }
    }

    private var backgroundColor: Color {
        if cell.isWrong { return Color.red.opacity(isSelected ? 0.25 : 0.12) }
        if isSelected { return Color.accentColor.opacity(0.35) }
        if isSameValue { return Color.accentColor.opacity(0.22) }
        if isHighlighted { return Color.accentColor.opacity(0.10) }
        return Color(.systemBackground)
    }

    private var digitColor: Color {
        if cell.isWrong { return .red }
        if cell.isHint { return .green }
        if cell.isGiven { return Color(.label) }
        return .accentColor
    }

    private var accessibilityDescription: String {
        let position = "Row \(row + 1), column \(col + 1)"
        if let value = cell.value {
            let kind = cell.isWrong ? ", incorrect" : cell.isHint ? ", hint" : cell.isGiven ? ", given" : ""
            return "\(position). \(value)\(kind)"
        }
        if !cell.pencilMarks.isEmpty {
            let notes = cell.pencilMarks.sorted().map(String.init).joined(separator: ", ")
            return "\(position). Empty, notes \(notes)"
        }
        return "\(position). Empty"
    }
}

private struct PencilMarksView: View {
    let marks: Set<Int>
    let fontSize: CGFloat

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let digit = row * 3 + col + 1
                        Text(marks.contains(digit) ? "\(digit)" : " ")
                            .font(.system(size: fontSize))
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(2)
    }
}
