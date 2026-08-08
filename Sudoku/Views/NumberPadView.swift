import SwiftUI

struct NumberPadView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...9, id: \.self) { digit in
                    Button {
                        vm.enterValue(digit)
                    } label: {
                        Text("\(digit)")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .foregroundStyle(Color(.label))
                }
            }

            HStack(spacing: 12) {
                ActionButton(
                    title: "Undo",
                    systemImage: "arrow.uturn.backward",
                    tint: vm.canUndo ? Color(.label) : Color(.tertiaryLabel),
                    action: vm.undo
                )
                .disabled(!vm.canUndo)

                ActionButton(
                    title: "Erase",
                    systemImage: "delete.left",
                    tint: Color(.label),
                    action: vm.erase
                )

                ActionButton(
                    title: "Notes",
                    systemImage: vm.gameState.isPencilMode ? "pencil.circle.fill" : "pencil.circle",
                    tint: vm.gameState.isPencilMode ? Color.accentColor : Color(.label),
                    background: vm.gameState.isPencilMode ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground),
                    action: vm.togglePencilMode
                )

                ActionButton(
                    title: "Hint (\(vm.gameState.hintsRemaining))",
                    systemImage: "lightbulb",
                    tint: vm.gameState.hintsRemaining > 0 ? Color.accentColor : Color(.tertiaryLabel),
                    action: vm.useHint
                )
                .disabled(vm.gameState.hintsRemaining == 0)
            }
        }
        .padding(.horizontal)
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    var tint: Color
    var background: Color = Color(.secondarySystemBackground)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .foregroundStyle(tint)
    }
}
