import SwiftUI

struct TimerView: View {
    let seconds: Int

    var body: some View {
        Text(formatted)
            .font(.system(.title3, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private var formatted: String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
