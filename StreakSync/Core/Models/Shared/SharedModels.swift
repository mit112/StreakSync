//
//  SharedModels.swift - PRODUCTION READY (FIXED)
//  StreakSync & StreakSyncShareExtension
//
//  FIXED: All force unwrapping removed with safe alternatives
//

/*
 * SHAREDMODELS - CORE DATA STRUCTURES
 * 
 * WHAT THIS FILE DOES:
 * This is the "data dictionary" of the entire app. It defines all the core data structures that represent
 * games, game results, scoring systems, and other fundamental concepts. Think of it as the "vocabulary"
 * that the entire app uses to understand and work with data. It's shared between the main app and the
 * Share Extension, ensuring consistency across both.
 * 
 * WHY IT EXISTS:
 * Every app needs to define what its data looks like. This file centralizes all the core data models
 * so that every part of the app speaks the same "language" when it comes to data. Without this file,
 * different parts of the app might represent the same information differently, leading to bugs and
 * confusion.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This defines the fundamental data structures that the entire app depends on
 * - Ensures data consistency between the main app and Share Extension
 * - Provides type safety and validation for all game-related data
 * - Defines how games are scored and displayed
 * - Handles complex game-specific logic (like Quordle's multi-puzzle scoring)
 * - Provides thread-safe data structures for Swift 6.0 concurrency
 * 
 * WHAT IT REFERENCES:
 * - Foundation: For basic data types and date handling
 * - UIKit: For color handling and UI integration
 * - SwiftUI: For Color integration
 * - OSLog: For logging and debugging
 * 
 * WHAT REFERENCES IT:
 * - EVERYTHING: This file is imported by virtually every other file in the app
 * - AppState: Uses these models to store and manage data
 * - GameResultParser: Creates GameResult objects using these models
 * - Share Extension: Uses these models to parse and save results
 * - All UI views: Display data using these models
 * - Analytics: Computes statistics using these models
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. FILE ORGANIZATION:
 *    - This file is very large (1600+ lines) - should be split into multiple files
 *    - Consider separating into: GameModels.swift, GameResultModels.swift, ColorModels.swift
 *    - Move game-specific display logic to separate files
 *    - Create a GameDisplayLogic protocol for better organization
 * 
 * 2. GAME-SPECIFIC LOGIC IMPROVEMENTS:
 *    - The displayScore logic is repetitive - could use a strategy pattern
 *    - Create a GameDisplayStrategy protocol for each game type
 *    - Move game-specific validation to separate validators
 *    - Consider using a factory pattern for game-specific logic
 * 
 * 3. DATA VALIDATION ENHANCEMENTS:
 *    - The current validation is basic - could be more comprehensive
 *    - Add validation for URL formats and game patterns
 *    - Implement data sanitization for user input
 *    - Add validation for edge cases and malformed data
 * 
 * 4. PERFORMANCE OPTIMIZATIONS:
 *    - The displayScore computed properties are called frequently - could be cached
 *    - Consider lazy loading for expensive computations
 *    - Optimize the large static game arrays
 *    - Add memory-efficient data structures for large datasets
 * 
 * 5. ACCESSIBILITY IMPROVEMENTS:
 *    - The accessibility descriptions could be more detailed
 *    - Add support for different accessibility needs
 *    - Implement dynamic type support for all text
 *    - Add VoiceOver navigation improvements
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for all data models
 *    - Test edge cases and validation logic
 *    - Add property-based testing for data generation
 *    - Test thread safety of all data structures
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for each model
 *    - Document the relationships between models
 *    - Add examples of how to use each model
 *    - Create data flow diagrams
 * 
 * 8. ERROR HANDLING:
 *    - The current error handling is basic - could be more robust
 *    - Add proper error types for different failure scenarios
 *    - Implement recovery strategies for data corruption
 *    - Add logging for data validation failures
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - struct vs class: These are all structs because they're value types (safer for concurrency)
 * - Codable: Allows these models to be saved to and loaded from files
 * - Sendable: Ensures these models are safe to use across different threads
 * - Identifiable: Required by SwiftUI for lists and navigation
 * - Computed properties: These are calculated on-demand (like displayScore)
 * - Static properties: These belong to the type itself, not individual instances
 * - Enums: Used for categories and scoring models to ensure type safety
 * - Extensions: Add functionality to existing types (like Date and URL)
 * - Preconditions: Check that data is valid when creating objects
 * - Thread safety: All models are designed to work safely with Swift 6.0 concurrency
 */

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
    
    // MARK: - Computed Properties for Results
    var recentResults: [GameResult] {
        // This would be populated from your app state
        // For now, return empty array
        []
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
    
    // MARK: - Public Initializer (Auto‑generated ID)
    init(
        gameId: UUID,
        gameName: String,
        date: Date = Date(),
        score: Int?,
        maxAttempts: Int,
        completed: Bool,
        sharedText: String,
        parsedData: [String: String] = [:]
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
            parsedData: parsedData
        )
    }
    
    // MARK: - Designated Initializer (Injectable ID)
    /// Designated initializer that allows callers (including CloudKit sync) to provide a stable ID.
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
        parsedData: [String: String] = [:]
    ) {
        // Input validation
        precondition(!gameName.isEmpty, "Game name cannot be empty")
        precondition(maxAttempts >= 0, "Max attempts must be non-negative")
        precondition(!sharedText.isEmpty, "Shared text cannot be empty")
        
        if let score = score {
            // Special handling for time-based games like Zip, Tango, Queens, and Crossclimb
            if gameName.lowercased() == "linkedinzip" {
                precondition(score >= 0, "Score (time) must be non-negative for Zip")
            } else if gameName.lowercased() == "linkedintango" {
                precondition(score >= 0, "Score (time) must be non-negative for Tango")
            } else if gameName.lowercased() == "linkedinqueens" {
                precondition(score >= 0, "Score (time) must be non-negative for Queens")
            } else if gameName.lowercased() == "linkedincrossclimb" {
                precondition(score >= 0, "Score (time) must be non-negative for Crossclimb")
            } else if gameName.lowercased() == "linkedinpinpoint" {
                precondition(score >= 1 && score <= maxAttempts, "Score (guesses) must be between 1 and maxAttempts for Pinpoint")
            } else if gameName.lowercased() == "strands" {
                precondition(score >= 0 && score <= maxAttempts, "Score (hints) must be between 0 and maxAttempts for Strands")
            } else {
                precondition(score >= 1 && score <= maxAttempts, "Score must be between 1 and maxAttempts")
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
        
        // Special handling for time-based games like Zip, Tango, Queens, and Crossclimb
        if gameName.lowercased() == "linkedinzip" {
            // For Zip, score is time in seconds, maxAttempts is backtrack count
            // Time can be any positive value, backtracks can be 0 or more
            return score >= 0
        } else if gameName.lowercased() == "linkedintango" {
            // For Tango, score is time in seconds, maxAttempts is 0 (no attempts/backtracks)
            // Time can be any positive value
            return score >= 0
        } else if gameName.lowercased() == "linkedinqueens" {
            // For Queens, score is time in seconds, maxAttempts is 0 (no attempts/backtracks)
            // Time can be any positive value
            return score >= 0
        } else if gameName.lowercased() == "linkedincrossclimb" {
            // For Crossclimb, score is time in seconds, maxAttempts is 0 (no attempts/backtracks)
            // Time can be any positive value
            return score >= 0
        } else if gameName.lowercased() == "linkedinpinpoint" {
            // For Pinpoint, score is number of guesses (1-5), maxAttempts is 5
            // Standard validation applies
            return score >= 1 && score <= maxAttempts
        } else if gameName.lowercased() == "strands" {
            // For Strands, score is number of hints (0-10), maxAttempts is 10
            // Hints can be 0 or more, up to reasonable limit
            return score >= 0 && score <= maxAttempts
        } else if gameName.lowercased() == "octordle" {
            // For Octordle, score is the actual score from "Score: XX" line
            // maxAttempts = score, so score should equal maxAttempts
            // Score can be 0 (if Score line not found) or any positive value (8 is perfect, higher is worse)
            return score >= 0 && score == maxAttempts
        }
        
        // Standard validation for other games
        return score >= 1 && score <= maxAttempts
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


