//
//  EditGameResultViewModel.swift
//  StreakSync
//
//  ViewModel for editing an existing game result.
//

import Foundation
import OSLog

@MainActor
final class EditGameResultViewModel: ObservableObject {
    let original: GameResult
    let game: Game?

    @Published var completed: Bool
    @Published var scoreText: String
    @Published var date: Date

    private let logger = Logger(
        subsystem: "com.streaksync.app",
        category: "EditGameResultViewModel"
    )

    init(result: GameResult, game: Game?) {
        self.original = result
        self.game = game
        self.completed = result.completed
        self.scoreText = result.score.map { String($0) } ?? ""
        self.date = result.date
    }

    // MARK: - Computed State

    var hasChanges: Bool {
        completed != original.completed
        || parsedScore != original.score
        || !Calendar.current.isDate(date, inSameDayAs: original.date)
    }

    var isValid: Bool {
        guard hasChanges else { return false }
        if let text = scoreText.nilIfEmpty, Int(text) == nil {
            return false
        }
        if let score = parsedScore {
            return isScoreInRange(score)
        }
        return true
    }

    var scorePlaceholder: String {
        guard let game else { return "Score" }
        switch game.scoringModel {
        case .lowerAttempts:
            return "Attempts (1-\(maxAttemptsForGame))"
        case .lowerTimeSeconds:
            return "Time in seconds"
        case .lowerGuesses:
            return "Guesses (1-\(maxAttemptsForGame))"
        case .lowerHints:
            return "Hints (0-\(maxAttemptsForGame))"
        case .higherIsBetter:
            return "Score"
        }
    }

    var scoreLabel: String {
        guard let game else { return "Score" }
        switch game.scoringModel {
        case .lowerAttempts: return "Attempts"
        case .lowerTimeSeconds: return "Time (seconds)"
        case .lowerGuesses: return "Guesses"
        case .lowerHints: return "Hints Used"
        case .higherIsBetter: return "Score"
        }
    }

    var showsScore: Bool {
        original.score != nil || !(scoreText.isEmpty)
    }

    // MARK: - Actions

    func save(appState: AppState) async -> Bool {
        guard isValid else {
            logger.warning("Cannot save — validation failed")
            return false
        }

        let edited = original.replacing(
            date: date,
            score: parsedScore,
            completed: completed
        )

        guard edited.isValid else {
            logger.warning("Edited result failed isValid check")
            return false
        }

        await appState.editGameResult(original: original, edited: edited)
        logger.info("Saved edited result for \(self.original.gameName)")
        return true
    }

    // MARK: - Private Helpers

    private var parsedScore: Int? {
        guard let text = scoreText.nilIfEmpty else { return nil }
        return Int(text)
    }

    private var maxAttemptsForGame: Int {
        original.maxAttempts
    }

    private func isScoreInRange(_ score: Int) -> Bool {
        guard let game else { return score >= 0 }
        switch game.scoringModel {
        case .lowerAttempts:
            return score >= 1 && score <= maxAttemptsForGame
        case .lowerTimeSeconds:
            return score >= 0
        case .lowerGuesses:
            return score >= 1 && score <= maxAttemptsForGame
        case .lowerHints:
            return score >= 0 && score <= maxAttemptsForGame
        case .higherIsBetter:
            return score >= 0
        }
    }
}

// MARK: - String Helper
private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
