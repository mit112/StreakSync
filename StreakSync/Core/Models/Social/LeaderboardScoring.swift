//
//  LeaderboardScoring.swift
//  StreakSync
//
//  Centralized scoring and label formatting for leaderboard aggregation.
//

import Foundation

enum LeaderboardScoring {
    /// Compute positive points where larger is better for ranking within a game.
    /// Uses the game's `scoringModel` to normalize values into a 1...7 range where possible.
    static func points(for score: DailyGameScore, game: Game?) -> Int {
        guard score.completed else { return 0 }
        guard let game = game else {
            // Fallback to attempts-based if game not found
            return attemptsPoints(score: score)
        }
        switch game.scoringModel {
        case .lowerAttempts, .lowerGuesses:
            return attemptsPoints(score: score)
        case .lowerHints:
            // Fewer hints is better
            guard let used = score.score else { return 0 }
            let maxAttempts = max(1, score.maxAttempts)
            return max(0, maxAttempts - used + 1)
        case .higherIsBetter:
            // Cap to 7 for cross-game comparability in UI; rank is per-game page anyway
            guard let raw = score.score else { return 0 }
            return max(0, min(7, raw))
        case .lowerTimeSeconds:
            // Map time buckets to 1...7 where faster is higher
            guard let seconds = score.score else { return 0 }
            // 0-29:7, 30-59:6, 60-89:5, 90-119:4, 120-149:3, 150-179:2, >=180:1
            let bucket = max(0, min(6, seconds / 30))
            return 7 - bucket
        }
    }

    /// Human-readable metric text for the given game and computed points.
    /// This is used purely for display; ranking uses `points`.
    static func metricLabel(for game: Game, points: Int) -> String {
        switch game.scoringModel {
        case .lowerAttempts, .lowerGuesses:
            let attempts = max(1, 7 - max(0, points))
            return "\(attempts) guesses"
        case .lowerHints:
            let hints = max(0, 7 - max(0, points))
            return hints == 1 ? "1 hint" : "\(hints) hints"
        case .higherIsBetter:
            return points == 1 ? "1 pt" : "\(points) pts"
        case .lowerTimeSeconds:
            // Approximate visualization from points back to ranges
            let bucket = max(0, 7 - max(1, points))
            switch bucket {
            case 0: return "<30s"
            case 1: return "<1m"
            case 2: return "<1m30"
            case 3: return "<2m"
            case 4: return "<2m30"
            case 5: return "<3m"
            default: return ">=3m"
            }
        }
    }

    // MARK: - Helpers
    private static func attemptsPoints(score: DailyGameScore) -> Int {
        guard score.completed, let sc = score.score else { return 0 }
        return max(0, score.maxAttempts - sc + 1)
    }
}


