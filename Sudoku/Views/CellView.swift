import SwiftUI

struct CellView: View {
    let cell: Cell
    let onTap: () -> Void

    var body: some View {
        ZStack {
            background
            content
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var content: some View {
        if let value = cell.value {
            Text("\(value)")
                .font(.system(size: 22, weight: cell.isGiven ? .bold : .regular))
                .foregroundStyle(digitColor)
        } else if !cell.pencilMarks.isEmpty {
            PencilMarksView(marks: cell.pencilMarks)
        }
    }

    private var background: some View {
        Rectangle()
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if cell.isWrong { return Color.red.opacity(cell.isSelected ? 0.25 : 0.12) }
        if cell.isSelected { return Color.accentColor.opacity(0.35) }
        if cell.isSameValue { return Color.accentColor.opacity(0.22) }
        if cell.isHighlighted { return Color.accentColor.opacity(0.10) }
        return Color(.systemBackground)
    }

    private var digitColor: Color {
        if cell.isWrong { return .red }
        if cell.isHint { return .green }
        if cell.isGiven { return Color(.label) }
        return .accentColor
    }
}

private struct PencilMarksView: View {
    let marks: Set<Int>

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let digit = row * 3 + col + 1
                        Text(marks.contains(digit) ? "\(digit)" : " ")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(2)
    }
}
