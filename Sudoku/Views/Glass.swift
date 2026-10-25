import SwiftUI

extension View {
    /// Liquid Glass on iOS 26 and later; a plain rounded fill on earlier systems.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = 12, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tint?.opacity(0.2) ?? Color(.secondarySystemBackground))
            )
        }
    }

    /// `.glassProminent` on iOS 26 and later, `.borderedProminent` before.
    @ViewBuilder
    func prominentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

/// Groups sibling glass surfaces so iOS 26 renders them together (cheaper, and
/// lets neighbouring shapes blend). A pass-through on earlier systems.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
