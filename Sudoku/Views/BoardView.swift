import SwiftUI

struct BoardView: View {
    let vm: GameViewModel

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / 9
            let selRow = vm.gameState.selectedRow
            let selCol = vm.gameState.selectedCol
            let selectedValue = selRow.flatMap { r in selCol.flatMap { c in vm.board[r, c].value } }

            ZStack {
                // Cell grid. Highlights are derived from the selection here rather
                // than stored on every cell, so a tap only redraws cells that change.
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                let cell = vm.board[row, col]
                                let isSelected = row == selRow && col == selCol
                                let sharesUnit = selRow.map { sr in selCol.map { sc in
                                    row == sr || col == sc || (row / 3 == sr / 3 && col / 3 == sc / 3)
                                } ?? false } ?? false
                                CellView(
                                    cell: cell,
                                    row: row,
                                    col: col,
                                    isSelected: isSelected,
                                    isHighlighted: sharesUnit && !isSelected,
                                    isSameValue: !isSelected && selectedValue != nil && cell.value == selectedValue,
                                    size: cellSize
                                ) {
                                    vm.selectCell(row: row, col: col)
                                }
                                .equatable()
                            }
                        }
                    }
                }

                // Grid lines overlay
                Canvas { ctx, size in
                    drawGrid(ctx: ctx, size: size)
                }
                .frame(width: size, height: size)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let cell = size.width / 9

        for i in 0...9 {
            let x = CGFloat(i) * cell
            let y = CGFloat(i) * cell
            let isBox = i % 3 == 0
            let width: CGFloat = isBox ? 2.5 : 0.5
            let color = isBox ? Color(.label) : Color(.separator)

            // Vertical
            var vPath = Path()
            vPath.move(to: CGPoint(x: x, y: 0))
            vPath.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(vPath, with: .color(color), lineWidth: width)

            // Horizontal
            var hPath = Path()
            hPath.move(to: CGPoint(x: 0, y: y))
            hPath.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(hPath, with: .color(color), lineWidth: width)
        }
    }
}
