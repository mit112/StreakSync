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
            // Fewer hints is better; normalize against maxAttempts so a game with a
            // large hint budget (e.g. Strands) can't exceed the shared 1...7 scale.
            guard let used = score.score else { return 0 }
            return normalizedPoints(value: used, worst: score.maxAttempts)
        case .higherIsBetter:
            // Cap to 7 for cross-game comparability in UI; rank is per-game page anyway
            guard let raw = score.score else { return 0 }
            return max(0, min(7, raw))
        case .lowerTimeSeconds:
            guard let seconds = score.score else { return 0 }
            // maxAttempts doubles as a plausible par time for games that carry one
            // (e.g. Pips: par varies by difficulty). When it's not a plausible par
            // (< 30 — Queens/Tango/Crossclimb/Zip pass 0), fall back to the original
            // fixed-bucket behavior those games were already tuned against.
            if score.maxAttempts >= 30 {
                return normalizedPoints(value: seconds, worst: score.maxAttempts)
            }
            // 0-29:7, 30-59:6, 60-89:5, 90-119:4, 120-149:3, 150-179:2, >=180:1
            let bucket = max(0, min(6, seconds / 30))
            return 7 - bucket
        }
    }

    /// Human-readable metric text for the given game and its raw `DailyGameScore.score`
    /// value (guesses, hints, or seconds — depending on `scoringModel`). This renders the
    /// true recorded metric; it never reconstructs a number from the normalized `points`
    /// used for ranking, which cannot be mapped back to a specific attempt/hint/time value.
    static func metricLabel(for game: Game, rawScore: Int?) -> String {
        guard let rawScore else { return "—" }
        switch game.scoringModel {
        case .lowerAttempts, .lowerGuesses:
            return rawScore == 1 ? "1 guess" : "\(rawScore) guesses"
        case .lowerHints:
            return rawScore == 1 ? "1 hint" : "\(rawScore) hints"
        case .higherIsBetter:
            return rawScore == 1 ? "1 pt" : "\(rawScore) pts"
        case .lowerTimeSeconds:
            let minutes = rawScore / 60
            let seconds = rawScore % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Helpers
    private static func attemptsPoints(score: DailyGameScore) -> Int {
        guard score.completed, let sc = score.score else { return 0 }
        return normalizedPoints(value: sc, worst: score.maxAttempts)
    }

    /// Maps a "lower is better" value into a shared 1...7 scale, proportional to
    /// how far it sits between best (1) and `worst` (the worst plausible value).
    /// Keeps games with very different raw scales (e.g. Wordle's 6 guesses vs.
    /// Quordle's 36-point total) directly comparable for cross-game ranking.
    private static func normalizedPoints(value: Int, worst: Int) -> Int {
        guard worst > 1 else { return 7 }
        let clamped = max(1, min(worst, value))
        let ratio = Double(worst - clamped) / Double(worst - 1)
        let points = Int(round(ratio * 6)) + 1
        return max(1, min(7, points))
    }
}
