import SwiftUI

struct NumberPadView: View {
    let vm: GameViewModel
    @ScaledMetric(relativeTo: .title2) private var keyHeight: CGFloat = 56

    var body: some View {
        GlassGroup(spacing: 4) {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(1...9, id: \.self) { digit in
                        digitKey(digit)
                    }
                }

                HStack(spacing: 8) {
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
                        glassTint: vm.gameState.isPencilMode ? Color.accentColor.opacity(0.3) : nil,
                        action: vm.togglePencilMode
                    )
                    .accessibilityValue(vm.gameState.isPencilMode ? "On" : "Off")

                    ActionButton(
                        title: "Hint (\(vm.gameState.hintsRemaining))",
                        systemImage: "lightbulb",
                        tint: vm.gameState.hintsRemaining > 0 ? Color.accentColor : Color(.tertiaryLabel),
                        action: vm.useHint
                    )
                    .disabled(vm.gameState.hintsRemaining == 0)
                    .accessibilityLabel("Hint, \(vm.gameState.hintsRemaining) left")
                }
            }
        }
        .padding(.horizontal)
        // The pad has a fixed nine-across layout; beyond this size the digits
        // would no longer fit, so cap scaling here.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func digitKey(_ digit: Int) -> some View {
        let remaining = vm.remainingCount(of: digit)
        return Button {
            vm.enterValue(digit)
        } label: {
            VStack(spacing: 0) {
                Text("\(digit)")
                    .font(.title2.weight(.semibold))
                Text("\(remaining)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: keyHeight)
            .glassSurface(cornerRadius: 10, interactive: true)
        }
        .foregroundStyle(Color(.label))
        .disabled(remaining == 0)
        .opacity(remaining == 0 ? 0.3 : 1)
        .accessibilityLabel(remaining == 0 ? "\(digit), all placed" : "\(digit), \(remaining) left")
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    var tint: Color
    var glassTint: Color? = nil
    let action: () -> Void
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 52

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .glassSurface(cornerRadius: 10, tint: glassTint, interactive: true)
        }
        .foregroundStyle(tint)
    }
}
