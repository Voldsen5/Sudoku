import SwiftUI

struct TimerView: View {
    let seconds: Int

    var body: some View {
        Text(formatClock(seconds))
            .font(.system(.title3, design: .monospaced))
            .foregroundStyle(.secondary)
            .accessibilityLabel("Time \(seconds / 60) minutes \(seconds % 60) seconds")
    }
}

/// Formats elapsed seconds as `mm:ss`.
func formatClock(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
