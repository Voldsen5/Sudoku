import SwiftUI

struct ContentView: View {
    @State private var showGame = false
    @State private var vm: GameViewModel?
    @State private var savedGame: SavedGame? = nil
    @State private var showOverwriteAlert = false
    @State private var showDifficultyCards = false
    @State private var stats = StatsStore.load()
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Sudoku")
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    Text("Fill the grid, one number at a time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    // Resume saved game
                    if let saved = savedGame {
                        let difficulty = Difficulty(rawValue: saved.difficulty) ?? .medium
                        Button {
                            let resumeVM = GameViewModel(difficulty: difficulty)
                            resumeVM.resumeGame(from: saved)
                            vm = resumeVM
                            showGame = true
                        } label: {
                            VStack(spacing: 2) {
                                Text("Resume Game")
                                    .font(.title3.bold())
                                HStack(spacing: 12) {
                                    Text(difficulty.displayName)
                                    Text(formatClock(saved.elapsedSeconds))
                                        .monospaced()
                                }
                                .font(.caption)
                                .opacity(0.85)
                            }
                            .frame(minWidth: 220, minHeight: 52)
                        }
                        .prominentButtonStyle()
                        .tint(.green)
                        .accessibilityLabel("Resume \(difficulty.displayName) game")
                    }

                    if !showDifficultyCards {
                        Button {
                            if savedGame != nil {
                                showOverwriteAlert = true
                            } else {
                                withAnimation(pickerAnimation) {
                                    showDifficultyCards = true
                                }
                            }
                        } label: {
                            Text("New Game")
                                .font(.title3.bold())
                                .frame(minWidth: 220, minHeight: 44)
                        }
                        .prominentButtonStyle()
                        .alert("Abandon current game?", isPresented: $showOverwriteAlert) {
                            Button("Abandon & Start New", role: .destructive) {
                                GamePersistence.abandon()
                                savedGame = nil
                                stats = StatsStore.load()
                                withAnimation(pickerAnimation) {
                                    showDifficultyCards = true
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(stats.currentStreak > 0
                                 ? "Your unfinished game will be discarded and counted as a loss, ending your \(stats.currentStreak)-game win streak."
                                 : "Your unfinished game will be discarded and counted as a loss.")
                        }
                    }
                }

                // Difficulty cards
                if showDifficultyCards {
                    GlassGroup(spacing: 10) {
                        VStack(spacing: 10) {
                            Text("Choose difficulty")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ForEach(Difficulty.allCases) { difficulty in
                                DifficultyCard(difficulty: difficulty) {
                                    startNewGame(difficulty: difficulty)
                                }
                            }

                            Button {
                                withAnimation(pickerAnimation) {
                                    showDifficultyCards = false
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                if stats.totalWins > 0 {
                    HStack(spacing: 16) {
                        Label("\(stats.totalWins) won", systemImage: "checkmark.seal")
                        Label("Streak \(stats.currentStreak)", systemImage: "flame")
                        Label("Best streak \(stats.bestStreak)", systemImage: "trophy")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .background(backdrop)
            .onAppear {
                savedGame = GamePersistence.load()
                stats = StatsStore.load()
            }
            .navigationDestination(isPresented: $showGame) {
                if let vm {
                    GameView(vm: vm)
                        .onDisappear {
                            savedGame = GamePersistence.load()
                            stats = StatsStore.load()
                        }
                }
            }
        }
    }

    private var pickerAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35)
    }

    /// A soft colour wash gives the glass buttons and cards something to refract.
    private var backdrop: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.18), Color(.systemBackground), Color.green.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func startNewGame(difficulty: Difficulty) {
        let newVM = GameViewModel(difficulty: difficulty)
        vm = newVM
        // Collapse the picker now (no animation) so it isn't briefly visible
        // behind the game when the user navigates back.
        showDifficultyCards = false
        showGame = true
    }
}

private struct DifficultyCard: View {
    let difficulty: Difficulty
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(difficulty.displayName)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Text(difficulty.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let best = StatsStore.bestSeconds(for: difficulty) {
                        Label(formatClock(best), systemImage: "trophy")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Best time \(formatClock(best))")
                    }
                }
                Spacer()
                Text(difficulty.badge)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.15))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassSurface(cornerRadius: 14, interactive: true)
        }
    }

    private var badgeColor: Color {
        switch difficulty {
        case .easy:   return .green
        case .medium: return .accentColor
        case .hard:   return .red
        }
    }
}
