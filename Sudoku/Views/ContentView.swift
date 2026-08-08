import SwiftUI

struct ContentView: View {
    @State private var showGame = false
    @State private var vm: GameViewModel?
    @State private var savedGame: SavedGame? = nil
    @State private var showOverwriteAlert = false
    @State private var showDifficultyCards = false
    @State private var stats = StatsStore.load()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Sudoku")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Fill the grid, one number at a time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    // Resume saved game
                    if let saved = savedGame {
                        Button {
                            let resumeVM = GameViewModel(difficulty: Difficulty(rawValue: saved.difficulty) ?? .medium)
                            resumeVM.resumeGame(from: saved)
                            vm = resumeVM
                            showGame = true
                        } label: {
                            VStack(spacing: 2) {
                                Text("Resume Game")
                                    .font(.title3.bold())
                                HStack(spacing: 12) {
                                    Text((Difficulty(rawValue: saved.difficulty) ?? .medium).displayName)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text(formatTime(saved.elapsedSeconds))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .frame(width: 240, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.green)
                                    .shadow(color: Color.green.opacity(0.45), radius: 6, x: 0, y: 4)
                            )
                            .foregroundStyle(.white)
                        }
                    }

                    if !showDifficultyCards {
                        Button {
                            if savedGame != nil {
                                showOverwriteAlert = true
                            } else {
                                withAnimation(.spring(duration: 0.35)) {
                                    showDifficultyCards = true
                                }
                            }
                        } label: {
                            Text("New Game")
                                .font(.title3.bold())
                                .frame(width: 240, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.accentColor)
                                        .shadow(color: Color.accentColor.opacity(0.45), radius: 6, x: 0, y: 4)
                                )
                                .foregroundStyle(.white)
                        }
                        .alert("Abandon current game?", isPresented: $showOverwriteAlert) {
                            Button("Abandon & Start New", role: .destructive) {
                                GamePersistence.clear()
                                savedGame = nil
                                withAnimation(.spring(duration: 0.35)) {
                                    showDifficultyCards = true
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("You have an unfinished game. Starting a new game will permanently discard it.")
                        }
                    }
                }

                // Difficulty cards
                if showDifficultyCards {
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
                            withAnimation(.spring(duration: 0.35)) {
                                showDifficultyCards = false
                            }
                        } label: {
                            Text("Cancel")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private func startNewGame(difficulty: Difficulty) {
        let newVM = GameViewModel(difficulty: difficulty)
        vm = newVM
        // Collapse the picker now (no animation) so it isn't briefly visible
        // behind the game when the user navigates back.
        showDifficultyCards = false
        showGame = true
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(.label))
                    Text(difficulty.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let best = StatsStore.bestSeconds(for: difficulty) {
                        Label(formatTime(best), systemImage: "trophy")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(difficulty.badge)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeBackground)
                    .foregroundStyle(badgeForeground)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
            )
        }
    }

    private var badgeBackground: Color {
        switch difficulty.badgeColor {
        case "green": return Color.green.opacity(0.15)
        case "red":   return Color.red.opacity(0.15)
        default:      return Color.accentColor.opacity(0.15)
        }
    }

    private var badgeForeground: Color {
        switch difficulty.badgeColor {
        case "green": return Color.green
        case "red":   return Color.red
        default:      return Color.accentColor
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
