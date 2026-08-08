import SwiftUI

struct GameView: View {
    @ObservedObject var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
                    }
                }
                .padding(.horizontal)

                BoardView(vm: vm)
                    .padding(.horizontal, 4)
                    .blur(radius: vm.gameState.status == .paused ? 18 : 0)

                if vm.gameState.status == .playing || vm.gameState.status == .paused {
                    NumberPadView(vm: vm)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Sudoku")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                        .buttonStyle(.borderedProminent)
                }
            }

            // Win overlay
            if vm.gameState.status == .won {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Puzzle Solved!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text(formatTime(vm.gameState.elapsedSeconds))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                    if vm.isNewBestTime {
                        Label("New best time!", systemImage: "trophy.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                    }
                    Text("Win streak: \(StatsStore.load().currentStreak)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Button("New Game") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
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
                        .buttonStyle(.borderedProminent)
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
        .task {
            if vm.isResumed {
                vm.startTimer()
            } else {
                await vm.startGame()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                vm.persist()
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
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
    }
}
