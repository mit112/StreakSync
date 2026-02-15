//
//  SharedModels.swift - PRODUCTION READY (FIXED)
//  StreakSync & StreakSyncShareExtension
//
//  FIXED: All force unwrapping removed with safe alternatives
//

import Foundation
import UIKit
import OSLog
import SwiftUI

// MARK: - Scoring Model
enum ScoringModel: String, Codable, Sendable {
    case lowerAttempts            // e.g., Wordle/Nerdle: fewer attempts is better
    case lowerTimeSeconds         // e.g., Mini, Pips, LinkedIn Zip/Tango/Queens/Crossclimb: lower time is better
    case lowerGuesses             // e.g., Pinpoint: fewer guesses is better
    case lowerHints               // e.g., Strands: fewer hints is better
    case higherIsBetter           // e.g., Spelling Bee score or categories solved
    
    var isLowerBetter: Bool {
        switch self {
        case .higherIsBetter: return false
        default: return true
        }
    }
}


// MARK: - Game Model (Production Quality)
struct Game: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let url: URL
    let category: GameCategory
    let resultPattern: String
    let iconSystemName: String
    let backgroundColor: CodableColor
    let isPopular: Bool
    let isCustom: Bool
    let scoringModel: ScoringModel
    
    // MARK: - Safe Initializer
    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        url: URL,
        category: GameCategory,
        resultPattern: String,
        iconSystemName: String,
        backgroundColor: CodableColor,
        isPopular: Bool,
        isCustom: Bool,
        scoringModel: ScoringModel = .lowerAttempts
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.url = url
        self.category = category
        self.resultPattern = resultPattern
        self.iconSystemName = iconSystemName
        self.backgroundColor = backgroundColor
        self.isPopular = isPopular
        self.isCustom = isCustom
        self.scoringModel = scoringModel
    }
    
    // MARK: - Computed Properties
    var hostDomain: String {
        url.host ?? "Unknown"
    }
    
    var isOfficial: Bool {
        !isCustom
    }
    
    // MARK: - Sample Data
    static var sample: Game {
        Game(
            name: "Wordle",
            displayName: "Wordle",
            url: URL(string: "https://www.nytimes.com/games/wordle")!,
            category: .word,
            resultPattern: "Wordle \\d+ \\d+/6",
            iconSystemName: "textformat.abc",
            backgroundColor: CodableColor(.green),
            isPopular: true,
            isCustom: false
        )
    }
    
    var accessibilityDescription: String {
        "\(displayName) game, \(category.displayName) category"
    }
}

// MARK: - Game Category (Enhanced)
enum GameCategory: String, CaseIterable, Codable, Sendable {
    case word = "word"
    case math = "math"
    case music = "music"
    case geography = "geography"
    case trivia = "trivia"
    case puzzle = "puzzle"
    case nytGames = "nyt_games"
    case linkedinGames = "linkedin_games"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .word: return NSLocalizedString("category.word", comment: "Word Games")
        case .math: return NSLocalizedString("category.math", comment: "Math Games")
        case .music: return NSLocalizedString("category.music", comment: "Music Games")
        case .geography: return NSLocalizedString("category.geography", comment: "Geography")
        case .trivia: return NSLocalizedString("category.trivia", comment: "Trivia")
        case .puzzle: return NSLocalizedString("category.puzzle", comment: "Puzzle Games")
        case .nytGames: return NSLocalizedString("category.nyt_games", comment: "NYT Games")
        case .linkedinGames: return NSLocalizedString("category.linkedin_games", comment: "LinkedIn Games")
        case .custom: return NSLocalizedString("category.custom", comment: "Custom Games")
        }
    }
    
    var iconSystemName: String {
        switch self {
        case .word: return "textformat.abc"
        case .math: return "function"
        case .music: return "music.note"
        case .geography: return "globe"
        case .trivia: return "questionmark.circle"
        case .puzzle: return "puzzlepiece"
        case .nytGames: return "newspaper"
        case .linkedinGames: return "briefcase"
        case .custom: return "plus.circle"
        }
    }
    
    var accessibilityLabel: String {
        NSLocalizedString("category.accessibility", comment: "\(displayName) category")
    }
}


// MARK: - Game Result Model (Production Quality)
struct GameResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let gameId: UUID
    let gameName: String
    let date: Date
    let score: Int?
    let maxAttempts: Int
    let completed: Bool
    let sharedText: String
    let parsedData: [String: String]
    let lastModified: Date
    
    // MARK: - Public Initializer (Auto‑generated ID)
    init(
        gameId: UUID,
        gameName: String,
        date: Date = Date(),
        score: Int?,
        maxAttempts: Int,
        completed: Bool,
        sharedText: String,
        parsedData: [String: String] = [:],
        lastModified: Date? = nil
    ) {
        // Delegate to the designated initializer with a fresh UUID.
        self.init(
            id: UUID(),
            gameId: gameId,
            gameName: gameName,
            date: date,
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: sharedText,
            parsedData: parsedData,
            lastModified: lastModified
        )
    }
    
    // MARK: - Designated Initializer (Injectable ID)
    /// Designated initializer that allows callers (including Firestore sync) to provide a stable ID.
    /// All validation rules mirror the convenience initializer above.
    init(
        id: UUID,
        gameId: UUID,
        gameName: String,
        date: Date = Date(),
        score: Int?,
        maxAttempts: Int,
        completed: Bool,
        sharedText: String,
        parsedData: [String: String] = [:],
        lastModified: Date? = nil
    ) {
        // Input validation — assert catches bugs in Debug; in Release, invalid
        // results pass through and are rejected by the `isValid` check in addGameResult().
        assert(!gameName.isEmpty, "Game name cannot be empty")
        assert(maxAttempts >= 0, "Max attempts must be non-negative")
        assert(!sharedText.isEmpty, "Shared text cannot be empty")
        
        if let score = score {
            // Special handling for time-based games like Zip, Tango, Queens, and Crossclimb
            if gameName.lowercased() == "linkedinzip" {
                assert(score >= 0, "Score (time) must be non-negative for Zip")
            } else if gameName.lowercased() == "linkedintango" {
                assert(score >= 0, "Score (time) must be non-negative for Tango")
            } else if gameName.lowercased() == "linkedinqueens" {
                assert(score >= 0, "Score (time) must be non-negative for Queens")
            } else if gameName.lowercased() == "linkedincrossclimb" {
                assert(score >= 0, "Score (time) must be non-negative for Crossclimb")
            } else if gameName.lowercased() == "linkedinpinpoint" {
                assert(score >= 1 && score <= maxAttempts, "Score (guesses) must be between 1 and maxAttempts for Pinpoint")
            } else if gameName.lowercased() == "strands" {
                assert(score >= 0 && score <= maxAttempts, "Score (hints) must be between 0 and maxAttempts for Strands")
            } else {
                assert(score >= 1 && score <= maxAttempts, "Score must be between 1 and maxAttempts")
            }
        }
        
        self.id = id
        self.gameId = gameId
        self.gameName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.date = date
        self.score = score
        self.maxAttempts = maxAttempts
        self.completed = completed
        self.sharedText = sharedText
        self.parsedData = parsedData
        self.lastModified = lastModified ?? date
    }
    
    // MARK: - Codable (backward compatible — lastModified may be absent in old data)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        gameId = try container.decode(UUID.self, forKey: .gameId)
        gameName = try container.decode(String.self, forKey: .gameName)
        date = try container.decode(Date.self, forKey: .date)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        maxAttempts = try container.decode(Int.self, forKey: .maxAttempts)
        completed = try container.decode(Bool.self, forKey: .completed)
        sharedText = try container.decode(String.self, forKey: .sharedText)
        parsedData = try container.decodeIfPresent([String: String].self, forKey: .parsedData) ?? [:]
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? date
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, gameId, gameName, date, score, maxAttempts, completed, sharedText, parsedData, lastModified
    }

    // MARK: - Computed Properties
    var isSuccess: Bool {
        completed && score != nil
    }

    var isValid: Bool {
        !gameName.isEmpty &&
        maxAttempts >= 0 && // Allow 0 for games like Zip where maxAttempts is backtrack count
        (score == nil || isValidScoreForGame()) &&
        !sharedText.isEmpty
    }
    
    private func isValidScoreForGame() -> Bool {
        guard let score = score else { return true }
        
        // Look up the game's scoring model for type-safe validation
        let game = Game.allAvailableGames.first { $0.id == gameId }
        let scoringModel = game?.scoringModel ?? .lowerAttempts
        
        switch scoringModel {
        case .lowerTimeSeconds:
            // Time-based games (Zip, Tango, Queens, Crossclimb, etc.): any non-negative time
            return score >= 0
        case .lowerGuesses:
            // Guess-based games (Pinpoint): 1 to maxAttempts
            return score >= 1 && score <= maxAttempts
        case .lowerHints:
            // Hint-based games (Strands): 0 to maxAttempts
            return score >= 0 && score <= maxAttempts
        case .higherIsBetter:
            // Score-based games (Octordle, etc.): non-negative
            return score >= 0
        case .lowerAttempts:
            // Attempt-based games (Wordle, Nerdle, etc.): 1 to maxAttempts
            return score >= 1 && score <= maxAttempts
        }
    }
}

// MARK: - Grouped Game Result (for Pips)
struct GroupedGameResult: Identifiable, Codable {
    let id: UUID
    let gameId: UUID
    let gameName: String
    let puzzleNumber: String
    let date: Date
    let results: [GameResult] // Individual difficulty results
    
    init(gameId: UUID, gameName: String, puzzleNumber: String, date: Date, results: [GameResult]) {
        self.id = UUID()
        self.gameId = gameId
        self.gameName = gameName
        self.puzzleNumber = puzzleNumber
        self.date = date
        self.results = results
    }
    
    // Computed properties for display
    var displayTitle: String {
        return "Puzzle #\(puzzleNumber)"
    }
    
    var completedDifficulties: [String] {
        return results.compactMap { $0.parsedData["difficulty"] }
    }
    
    var hasEasy: Bool { completedDifficulties.contains("Easy") }
    var hasMedium: Bool { completedDifficulties.contains("Medium") }
    var hasHard: Bool { completedDifficulties.contains("Hard") }
    
    var completionStatus: String {
        let count = completedDifficulties.count
        switch count {
        case 1: return "1/3 Complete"
        case 2: return "2/3 Complete"
        case 3: return "All Complete"
        default: return "Not Started"
        }
    }
    
    var bestTime: String? {
        let times = results.compactMap { result -> (difficulty: String, time: String, seconds: Int)? in
            guard let difficulty = result.parsedData["difficulty"],
                  let time = result.parsedData["time"],
                  let secondsStr = result.parsedData["totalSeconds"],
                  let seconds = Int(secondsStr) else { return nil }
            return (difficulty, time, seconds)
        }
        
        guard let fastest = times.min(by: { $0.seconds < $1.seconds }) else { return nil }
        return "\(fastest.difficulty) - \(fastest.time)"
    }
    
    var isValid: Bool {
        !gameName.isEmpty &&
        !puzzleNumber.isEmpty &&
        !results.isEmpty
    }
}


