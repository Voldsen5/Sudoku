import SwiftUI

struct GameView: View {
    let vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// An overlay covers the board, so VoiceOver should only reach the overlay.
    private var isOverlayShown: Bool {
        vm.isLoading || vm.gameState.status != .playing
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                // Header
                ZStack {
                    MistakeView(count: vm.gameState.mistakeCount)

                    HStack {
                        VStack(alignment: .leading) {
                            Text(vm.gameState.difficulty.displayName)
                                .font(.headline)
                            TimerView(seconds: vm.gameState.elapsedSeconds)
                        }
                        Spacer()
                        Button {
                            vm.togglePause()
                        } label: {
                            Image(systemName: vm.gameState.status == .paused ? "play.circle" : "pause.circle")
                                .font(.title2)
                        }
                        .accessibilityLabel(vm.gameState.status == .paused ? "Resume" : "Pause")
                    }
                }
                .padding(.horizontal)

                BoardView(vm: vm)
                    .padding(.horizontal, 4)
                    .blur(radius: vm.gameState.status == .paused ? 18 : 0)
                    .accessibilityLabel("Sudoku board")

                if let message = vm.hintMessage {
                    Label(message, systemImage: "lightbulb.fill")
                        .font(.subheadline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassSurface(cornerRadius: 12, tint: .yellow.opacity(0.25))
                        .padding(.horizontal)
                        .transition(.opacity)
                }

                if vm.gameState.status == .playing || vm.gameState.status == .paused {
                    NumberPadView(vm: vm)
                }

                Spacer()
            }
            .padding(.top)
            .animation(.easeInOut(duration: 0.2), value: vm.hintMessage)
            .accessibilityHidden(isOverlayShown)
            .navigationTitle("Sudoku")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        vm.saveAndExit()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Menu")
                        }
                    }
                }
            }

            // Paused overlay
            if vm.gameState.status == .paused {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Paused")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Button("Resume") { vm.togglePause() }
                        .prominentButtonStyle()
                }
            }

            // Win overlay
            if vm.gameState.status == .won {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                WinPopup(
                    seconds: vm.gameState.elapsedSeconds,
                    isNewBestTime: vm.isNewBestTime,
                    streak: StatsStore.load().currentStreak,
                    onNewGame: { dismiss() }
                )
                .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            }

            // Game over overlay
            if vm.gameState.status == .lost {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Game Over")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("\(GameState.maxMistakes) mistakes — better luck next time!")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Button("Try Again") { dismiss() }
                        .prominentButtonStyle()
                        .tint(.red)
                }
                .padding(.horizontal, 32)
            }

            // Loading overlay
            if vm.isLoading {
                Color(.systemBackground).opacity(0.85)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Generating puzzle…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35),
                   value: vm.gameState.status == .won)
        .task {
            if vm.isResumed {
                vm.startTimer()
            } else {
                await vm.startGame()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { vm.pauseIfPlaying() }
            if newPhase == .background { vm.persist() }
        }
        .onChange(of: vm.hintMessage) { _, message in
            if let message {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }
}

/// A solid card (rather than text over a dimmed board) so the result and
/// streak stay easy to read in both light and dark mode.
private struct WinPopup: View {
    let seconds: Int
    let isNewBestTime: Bool
    let streak: Int
    let onNewGame: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Puzzle Solved!")
                .font(.title.bold())

            HStack(spacing: 12) {
                StatTile(title: "Time", value: formatClock(seconds), systemImage: "clock")
                StatTile(title: "Win streak", value: "\(streak)", systemImage: "flame.fill")
            }

            if isNewBestTime {
                Label("New best time!", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            Button(action: onNewGame) {
                Text("New Game")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .prominentButtonStyle()
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.popupBackground)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.popupTile))
        .accessibilityElement(children: .combine)
    }
}

private extension Color {
    /// Pure black in dark mode would vanish against the dimmed board, so the
    /// popup uses the raised greys iOS gives its own sheets.
    static let popupBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground
    })
    static let popupTile = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .tertiarySystemBackground : .secondarySystemBackground
    })
}

private struct MistakeView: View {
    let count: Int

    var body: some View {
        let livesRemaining = GameState.maxMistakes - count
        HStack(spacing: 6) {
            ForEach(0..<GameState.maxMistakes, id: \.self) { i in
                let alive = i < livesRemaining
                Image(systemName: alive ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(alive ? Color.red : Color(.tertiaryLabel))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(livesRemaining) of \(GameState.maxMistakes) lives left")
    }
}
