import SwiftUI

struct BoardView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / 9

            ZStack {
                // Cell grid
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                CellView(cell: vm.board[row, col]) {
                                    vm.selectCell(row: row, col: col)
                                }
                                .frame(width: cellSize, height: cellSize)
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
