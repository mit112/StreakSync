//
//  SharedModels.swift
//  StreakSync & StreakSyncShareExtension
//
//  Models shared between the app and the Share Extension
//

import Foundation
import OSLog
import SwiftUI
import UIKit

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
    let iconSystemName: String
    let backgroundColor: CodableColor
    let isPopular: Bool
    let scoringModel: ScoringModel

    // MARK: - Safe Initializer
    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        url: URL,
        category: GameCategory,
        iconSystemName: String,
        backgroundColor: CodableColor,
        isPopular: Bool,
        scoringModel: ScoringModel = .lowerAttempts
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.url = url
        self.category = category
        self.iconSystemName = iconSystemName
        self.backgroundColor = backgroundColor
        self.isPopular = isPopular
        self.scoringModel = scoringModel
    }

    // MARK: - Computed Properties
    var hostDomain: String {
        url.host ?? "Unknown"
    }

    // MARK: - Sample Data
    static var sample: Game {
        Game(
            name: "Wordle",
            displayName: "Wordle",
            url: URL(string: "https://www.nytimes.com/games/wordle") ?? URL(fileURLWithPath: "/"),
            category: .word,
            iconSystemName: "textformat.abc",
            backgroundColor: CodableColor(.green),
            isPopular: true
        )
    }
    
    var accessibilityDescription: String {
        "\(displayName) game, \(category.displayName) category"
    }
}

// MARK: - Game.Names Constants
extension Game {
    enum Names {
        static let wordle = "wordle"
        static let quordle = "quordle"
        static let nerdle = "nerdle"
        static let pips = "pips"
        static let connections = "connections"
        static let spellingBee = "spellingbee"
        static let miniCrossword = "minicrossword"
        static let strands = "strands"
        static let linkedinQueens = "linkedinqueens"
        static let linkedinTango = "linkedintango"
        static let linkedinCrossclimb = "linkedincrossclimb"
        static let linkedinPinpoint = "linkedinpinpoint"
        static let linkedinZip = "linkedinzip"
        static let linkedinMiniSudoku = "linkedinminisudoku"
        static let octordle = "octordle"
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
        "\(displayName) category"
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
        
        if let score {
            let scoringModel = Self.resolveScoringModel(gameId: gameId, gameName: gameName)
            assert(
                Self.isScoreValid(score, maxAttempts: maxAttempts, scoringModel: scoringModel),
                "Score does not match expected scoring model \(scoringModel.rawValue)"
            )
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

    // MARK: - Editing Support

    /// Creates a copy of this result with selectively overridden fields.
    /// Preserves the same `id` so the replacement swaps in-place.
    func replacing(
        date: Date? = nil,
        score: Int?? = nil,
        completed: Bool? = nil
    ) -> GameResult {
        GameResult(
            id: self.id,
            gameId: self.gameId,
            gameName: self.gameName,
            date: date ?? self.date,
            score: score ?? self.score,
            maxAttempts: self.maxAttempts,
            completed: completed ?? self.completed,
            sharedText: self.sharedText,
            parsedData: self.parsedData,
            lastModified: Date()
        )
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
        guard let score else { return true }
        let scoringModel = Self.resolveScoringModel(gameId: gameId, gameName: gameName)
        return Self.isScoreValid(score, maxAttempts: maxAttempts, scoringModel: scoringModel)
    }

    private static func isScoreValid(_ score: Int, maxAttempts: Int, scoringModel: ScoringModel) -> Bool {
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

    private static func resolveScoringModel(gameId: UUID, gameName: String) -> ScoringModel {
        if let game = Game.allAvailableGames.first(where: { $0.id == gameId }) {
            return game.scoringModel
        }

        let normalizedName = gameName
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let gameByName = Game.allAvailableGames.first(where: {
            $0.name.lowercased() == normalizedName || $0.displayName.lowercased() == normalizedName
        }) {
            return gameByName.scoringModel
        }

        return .lowerAttempts
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
    
    /// True when at least one difficulty has been recorded for this puzzle.
    ///
    /// Both call sites used to derive this by testing
    /// `completionStatus.contains("Completed")`. No case of `completionStatus` contains
    /// that substring — they are "1/3 Complete", "2/3 Complete", "All Complete" and
    /// "Not Started" — so the test was always false: the Pips month summary permanently
    /// read "0 completed" and Pips calendar days were never tinted.
    ///
    /// Known caveat, deliberately not changed here: `completedDifficulties` does not
    /// filter on `GameResult.completed`, so a failed attempt still counts. Fixing that
    /// changes which difficulty dots appear, which is a separate user-visible decision.
    var hasAnyCompletion: Bool { !completedDifficulties.isEmpty }

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

// MARK: - Game Detector

/// Maps shared text to a Game by checking for known signature strings.
/// Centralised here so both the main app and Share Extension use identical logic.
struct GameDetector {
    /// Detects which game a shared text snippet belongs to.
    ///
    /// Order matters: more specific checks (e.g. "Mini Crossword") must precede
    /// any potentially overlapping generic checks (e.g. a bare "Crossword").
    ///
    /// - Parameters:
    ///   - text: The raw shared text to inspect.
    ///   - games: The game catalog to search. Typically `Game.allAvailableGames`.
    /// - Returns: The matched `Game`, or `nil` if no rule fires.
    static func detect(from text: String, in games: [Game]) -> Game? {
        // Detection rules: (textContains, gameName), matched case-insensitively.
        // Ordered most-specific-first — a generic/bare marker (e.g. "Wordle") must
        // never pre-empt a more specific one that could legitimately co-occur in
        // the same share text (e.g. a combined multi-game LinkedIn post), so it
        // stays last.
        let rules: [(String, String)] = [
            ("Weekly Quordle Challenge", "quordle"),
            ("Daily Quordle", "quordle"),
            ("Daily Octordle", "octordle"),
            ("Pips #", "pips"),
            ("Strands #", "strands"),
            // Mini Crossword before any bare "Crossword" check
            ("Mini Crossword", "minicrossword"),
            ("Spelling Bee", "spellingbee"),
            // Widened from "Mini Sudoku #" to also catch "Mini Sudoku puzzle #45"
            // and "Mini Sudoku - May 19, 2026" share formats.
            ("Mini Sudoku", "linkedinminisudoku"),
            // Widened from "Queens #" to also catch the hashless "Queens 522" format.
            ("Queens", "linkedinqueens"),
            ("Tango #", "linkedintango"),
            ("Crossclimb #", "linkedincrossclimb"),
            ("Pinpoint #", "linkedinpinpoint"),
            ("Zip #", "linkedinzip"),
            // Widened from "nerdlegame" to also catch the branded "Nerdle 728 3/6" header.
            ("nerdle", "nerdle"),
            // Bare "Wordle" is the most generic marker in this list — kept last so
            // it can never pre-empt a more specific rule above.
            ("Wordle", "wordle")
        ]

        // Connections needs two markers to avoid false positives
        if text.range(of: "Connections", options: .caseInsensitive) != nil &&
            text.range(of: "Puzzle #", options: .caseInsensitive) != nil {
            return games.first { $0.name.lowercased() == "connections" }
        }

        for (marker, name) in rules {
            if text.range(of: marker, options: .caseInsensitive) != nil {
                return games.first { $0.name.lowercased() == name }
            }
        }

        return nil
    }
}
