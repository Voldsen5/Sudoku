import Foundation

struct DifficultyStats: Codable {
    var bestSeconds: Int? = nil
    var wins: Int = 0
}

struct GameStats: Codable {
    var perDifficulty: [String: DifficultyStats] = [:]
    var currentStreak: Int = 0
    var bestStreak: Int = 0

    var totalWins: Int {
        perDifficulty.values.reduce(0) { $0 + $1.wins }
    }
}

/// Persists best times, win counts, and streaks in UserDefaults.
enum StatsStore {
    /// Overridable so tests can use an isolated suite instead of the real store.
    nonisolated(unsafe) static var defaults = UserDefaults.standard
    private static let key = "gameStats"

    static func load() -> GameStats {
        guard let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(GameStats.self, from: data) else {
            return GameStats()
        }
        return stats
    }

    private static func save(_ stats: GameStats) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: key)
        }
    }

    /// Records a win. Returns true if it beat the previous best time.
    @discardableResult
    static func recordWin(difficulty: Difficulty, seconds: Int) -> Bool {
        var stats = load()
        var d = stats.perDifficulty[difficulty.rawValue] ?? DifficultyStats()

        var isNewBest = false
        if let best = d.bestSeconds {
            if seconds < best { d.bestSeconds = seconds; isNewBest = true }
        } else {
            d.bestSeconds = seconds
            isNewBest = true
        }
        d.wins += 1

        stats.perDifficulty[difficulty.rawValue] = d
        stats.currentStreak += 1
        stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
        save(stats)
        return isNewBest
    }

    static func recordLoss() {
        var stats = load()
        stats.currentStreak = 0
        save(stats)
    }

    static func bestSeconds(for difficulty: Difficulty) -> Int? {
        load().perDifficulty[difficulty.rawValue]?.bestSeconds
    }
}
