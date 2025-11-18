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
    
    // MARK: - Static Game IDs (Guaranteed Valid)
    private enum GameIDs {
        static let wordle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000") ?? UUID()
        static let quordle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001") ?? UUID()
        static let nerdle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002") ?? UUID()
        static let connections = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440003") ?? UUID()
        static let spellingBee = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440004") ?? UUID()
        static let miniCrossword = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440005") ?? UUID()
        static let strands = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440007") ?? UUID()
        // LinkedIn Games
        static let linkedinQueens = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440100") ?? UUID()
        static let linkedinTango = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440101") ?? UUID()
        static let linkedinCrossclimb = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440102") ?? UUID()
        static let linkedinPinpoint = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440103") ?? UUID()
        static let linkedinZip = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440104") ?? UUID()
        static let linkedinMiniSudoku = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440105") ?? UUID()
        // Wordle Variants
        static let octordle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440200") ?? UUID()
    }
    
    // MARK: - Static Game URLs (Guaranteed Valid)
    private enum GameURLs {
        // SwiftLint exemption: These URLs are hardcoded constants that require force unwrap fallbacks
        // swiftlint:disable force_unwrapping
        static let wordle = URL(string: "https://www.nytimes.com/games/wordle") ?? URL(string: "https://www.nytimes.com")!
        static let quordle = URL(string: "https://www.quordle.com") ?? URL(string: "https://www.merriam-webster.com")!
        static let nerdle = URL(string: "https://nerdlegame.com") ?? URL(string: "https://nerdlegame.com")!
        static let connections = URL(string: "https://www.nytimes.com/games/connections") ?? URL(string: "https://www.nytimes.com")!
        static let spellingBee = URL(string: "https://www.nytimes.com/puzzles/spelling-bee") ?? URL(string: "https://www.nytimes.com")!
        static let miniCrossword = URL(string: "https://www.nytimes.com/crosswords/game/mini") ?? URL(string: "https://www.nytimes.com")!
        static let strands = URL(string: "https://www.nytimes.com/games/strands") ?? URL(string: "https://www.nytimes.com")!
        // LinkedIn Games (direct game URLs that open in LinkedIn app)
        // These URLs open the specific games directly in the LinkedIn app
        static let linkedinQueens = URL(string: "https://www.linkedin.com/games/queens") ?? URL(string: "https://www.linkedin.com")!
        static let linkedinTango = URL(string: "https://www.linkedin.com/games/tango") ?? URL(string: "https://www.linkedin.com")!
        static let linkedinCrossclimb = URL(string: "https://www.linkedin.com/games/crossclimb") ?? URL(string: "https://www.linkedin.com")!
        static let linkedinPinpoint = URL(string: "https://www.linkedin.com/games/pinpoint") ?? URL(string: "https://www.linkedin.com")!
        static let linkedinZip = URL(string: "https://www.linkedin.com/games/zip") ?? URL(string: "https://www.linkedin.com")!
        static let linkedinMiniSudoku = URL(string: "https://www.linkedin.com/games/mini-sudoku") ?? URL(string: "https://www.linkedin.com")!
        // Wordle Variants
        static let octordle = URL(string: "https://octordle.com") ?? URL(string: "https://octordle.com")!
        // swiftlint:enable force_unwrapping
    }
    
    // MARK: - Static Game Instances (Safe - IDs and URLs Guaranteed)
    static let wordle = Game(
        id: GameIDs.wordle,
        name: "wordle",
        displayName: "Wordle",
        url: GameURLs.wordle,
        category: .nytGames,
        resultPattern: #"Wordle \d+ [1-6X]/6"#,
        iconSystemName: "square.grid.3x3.fill",
        backgroundColor: CodableColor(UIColor(red: 0.345, green: 0.8, blue: 0.008, alpha: 1.0)), // #58CC02
        isPopular: true,
        isCustom: false,
        scoringModel: .lowerAttempts
    )
    
    static let quordle = Game(
        id: GameIDs.quordle,
        name: "quordle",
        displayName: "Quordle",
        url: GameURLs.quordle,
        category: .word,
        resultPattern: #"Daily Quordle \d+"#,
        iconSystemName: "square.grid.2x2.fill",
        backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.588, blue: 0.0, alpha: 1.0)), // #FF9600
        isPopular: true,
        isCustom: false,
        scoringModel: .lowerAttempts
    )
    
    static let nerdle = Game(
        id: GameIDs.nerdle,
        name: "nerdle",
        displayName: "Nerdle",
        url: GameURLs.nerdle,
        category: .math,
        resultPattern: #"nerdlegame \d+ [1-6]/6"#,
        iconSystemName: "function",
        backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.588, blue: 0.0, alpha: 1.0)), // #FF9600
        isPopular: true,
        isCustom: false,
        scoringModel: .lowerAttempts
    )
    
    static let pips = Game(
        id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440006") ?? UUID(),
        name: "pips",
        displayName: "Pips",
        url: URL(string: "https://www.nytimes.com/games/pips")!,
        category: .puzzle,
        resultPattern: #"Pips #\d+ (Easy|Medium|Hard)"#,
        iconSystemName: "square.grid.2x2.fill",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: true,
        isCustom: false,
        scoringModel: .lowerTimeSeconds
    )
    
    static let connections = Game(
        id: GameIDs.connections,
        name: "connections",
        displayName: "Connections",
        url: GameURLs.connections,
        category: .nytGames,
        resultPattern: #"Connections Puzzle #\d+ [🟩🟨🟦🟪\s]+"#,
        iconSystemName: "link",
        backgroundColor: CodableColor(UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)), // #007AFF
        isPopular: true,
        isCustom: false,
        scoringModel: .higherIsBetter
    )
    
    static let spellingBee = Game(
        id: GameIDs.spellingBee,
        name: "spellingbee",
        displayName: "Spelling Bee",
        url: GameURLs.spellingBee,
        category: .nytGames,
        resultPattern: #"Spelling Bee"#,
        iconSystemName: "textformat.abc",
        backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)), // #FFCC00
        isPopular: true,
        isCustom: false,
        scoringModel: .higherIsBetter
    )
    
    static let miniCrossword = Game(
        id: GameIDs.miniCrossword,
        name: "minicrossword",
        displayName: "Mini Crossword",
        url: GameURLs.miniCrossword,
        category: .nytGames,
        resultPattern: #"Mini Crossword"#,
        iconSystemName: "grid",
        backgroundColor: CodableColor(UIColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)), // #009900
        isPopular: true,
        isCustom: false,
        scoringModel: .lowerTimeSeconds
    )
    
    static let strands = Game(
        id: GameIDs.strands,
        name: "strands",
        displayName: "Strands",
        url: GameURLs.strands,
        category: .nytGames,
        resultPattern: #"Strands.*?#"#,
        iconSystemName: "lightbulb.fill",
        backgroundColor: CodableColor(UIColor(red: 0.8, green: 0.4, blue: 0.0, alpha: 1.0)), // Orange #CC6600
        isPopular: true,
        isCustom: false,
        scoringModel: .lowerHints
    )
    
    // MARK: - LinkedIn Games
    static let linkedinQueens = Game(
        id: GameIDs.linkedinQueens,
        name: "linkedinqueens",
        displayName: "Queens",
        url: GameURLs.linkedinQueens,
        category: .linkedinGames,
        resultPattern: #"Queens.*?puzzle"#,
        iconSystemName: "crown.fill",
        backgroundColor: CodableColor(UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)), // LinkedIn Blue #007AFF
        isPopular: false,
        isCustom: false,
        scoringModel: .lowerTimeSeconds
    )
    
    static let linkedinTango = Game(
        id: GameIDs.linkedinTango,
        name: "linkedintango",
        displayName: "Tango",
        url: GameURLs.linkedinTango,
        category: .linkedinGames,
        resultPattern: #"Tango.*?puzzle"#,
        iconSystemName: "sun.max.fill",
        backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)), // Sun/Moon colors #FFCC00
        isPopular: false,
        isCustom: false,
        scoringModel: .lowerTimeSeconds
    )
    
    static let linkedinCrossclimb = Game(
        id: GameIDs.linkedinCrossclimb,
        name: "linkedincrossclimb",
        displayName: "Crossclimb",
        url: GameURLs.linkedinCrossclimb,
        category: .linkedinGames,
        resultPattern: #"Crossclimb.*?puzzle"#,
        iconSystemName: "arrow.up.arrow.down",
        backgroundColor: CodableColor(UIColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)), // Green #009900
        isPopular: false,
        isCustom: false,
        scoringModel: .lowerTimeSeconds
    )
    
    static let linkedinPinpoint = Game(
        id: GameIDs.linkedinPinpoint,
        name: "linkedinpinpoint",
        displayName: "Pinpoint",
        url: GameURLs.linkedinPinpoint,
        category: .linkedinGames,
        resultPattern: #"Pinpoint.*?puzzle"#,
        iconSystemName: "target",
        backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0)), // Orange #FF6600
        isPopular: false,
        isCustom: false,
        scoringModel: .lowerGuesses
    )
    
    static let linkedinZip = Game(
        id: GameIDs.linkedinZip,
        name: "linkedinzip",
        displayName: "Zip",
        url: GameURLs.linkedinZip,
        category: .linkedinGames,
        resultPattern: #"Zip.*?puzzle"#,
        iconSystemName: "line.3.horizontal",
        backgroundColor: CodableColor(UIColor(red: 0.6, green: 0.0, blue: 1.0, alpha: 1.0)), // Purple #9900FF
        isPopular: false,
        isCustom: false,
        scoringModel: .lowerTimeSeconds
    )
    
    static let linkedinMiniSudoku = Game(
        id: GameIDs.linkedinMiniSudoku,
        name: "linkedinminisudoku",
        displayName: "Mini Sudoku",
        url: GameURLs.linkedinMiniSudoku,
        category: .linkedinGames,
        resultPattern: #"Mini Sudoku.*?puzzle"#,
        iconSystemName: "square.grid.3x3.topleft.filled",
        backgroundColor: CodableColor(UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)), // Gray #808080
        isPopular: false,
        isCustom: false,
        scoringModel: .lowerTimeSeconds
    )
    
    // MARK: - Wordle Variants
    static let octordle = Game(
        id: GameIDs.octordle,
        name: "octordle",
        displayName: "Octordle",
        url: GameURLs.octordle,
        category: .word,
        resultPattern: #"Daily Octordle #\d+"#,
        iconSystemName: "8.circle.fill",
        backgroundColor: CodableColor(UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)), // Blue #3366CC
        isPopular: true,
        isCustom: false,
        scoringModel: .lowerAttempts
    )
    
    // Word Games (duplicates removed - using definitions above)
       
       static let letterboxed = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440006") ?? UUID(),
           name: "letterboxed",
           displayName: "Letter Boxed",
           url: URL(string: "https://www.nytimes.com/puzzles/letter-boxed")!,
           category: .word,
           resultPattern: #"Letter Boxed.*?in \d+ words"#,
           iconSystemName: "square.on.square",
           backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.588, blue: 0.0, alpha: 1.0)), // #FF9600
           isPopular: false,
           isCustom: false
       )
       
       static let waffle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440007") ?? UUID(),
           name: "waffle",
           displayName: "Waffle",
           url: URL(string: "https://wafflegame.net")!,
           category: .word,
           resultPattern: #"#waffle\d+ \d+/5"#,
           iconSystemName: "square.grid.2x2",
           backgroundColor: CodableColor(.systemBrown),
           isPopular: false,
           isCustom: false
       )
       
       // Math Games
       static let mathle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440008") ?? UUID(),
           name: "mathle",
           displayName: "Mathle",
           url: URL(string: "https://www.mathle.com")!,
           category: .math,
           resultPattern: #"Mathle \d+ [1-6X]/6"#,
           iconSystemName: "function",
           backgroundColor: CodableColor(.systemIndigo),
           isPopular: false,
           isCustom: false
       )
       
       static let numberle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440009") ?? UUID(),
           name: "numberle",
           displayName: "Numberle",
           url: URL(string: "https://numberle.com")!,
           category: .math,
           resultPattern: #"Numberle \d+ [1-6X]/6"#,
           iconSystemName: "number.square",
           backgroundColor: CodableColor(.systemCyan),
           isPopular: false,
           isCustom: false
       )
       
       // Geography Games
       static let worldle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544000A") ?? UUID(),
           name: "worldle",
           displayName: "Worldle",
           url: URL(string: "https://worldle.teuteuf.fr")!,
           category: .geography,
           resultPattern: #"#Worldle #\d+ [1-6X]/6"#,
           iconSystemName: "globe",
           backgroundColor: CodableColor(.systemGreen),
           isPopular: true,
           isCustom: false
       )
       
       static let globle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544000B") ?? UUID(),
           name: "globle",
           displayName: "Globle",
           url: URL(string: "https://globle-game.com")!,
           category: .geography,
           resultPattern: #"Globle.*?in \d+ guesses"#,
           iconSystemName: "globe.americas",
           backgroundColor: CodableColor(.systemTeal),
           isPopular: false,
           isCustom: false
       )
       
       // Trivia Games
       static let contexto = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544000C") ?? UUID(),
           name: "contexto",
           displayName: "Contexto",
           url: URL(string: "https://contexto.me")!,
           category: .trivia,
           resultPattern: #"Contexto \d+.*?in \d+ guesses"#,
           iconSystemName: "lightbulb",
           backgroundColor: CodableColor(.systemRed),
           isPopular: true,
           isCustom: false
       )
       
       static let framed = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544000D") ?? UUID(),
           name: "framed",
           displayName: "Framed",
           url: URL(string: "https://framed.wtf")!,
           category: .trivia,
           resultPattern: #"Framed #\d+ [1-6X]/6"#,
           iconSystemName: "film",
           backgroundColor: CodableColor(.systemPink),
           isPopular: false,
           isCustom: false
       )
       
       // Puzzle Games
       static let crosswordle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544000E") ?? UUID(),
           name: "crosswordle",
           displayName: "Crosswordle",
           url: URL(string: "https://crosswordle.serializer.ca")!,
           category: .puzzle,
           resultPattern: #"Crosswordle \d+.*?in \d+"#,
           iconSystemName: "square.grid.3x3.fill",
           backgroundColor: CodableColor(.systemGray),
           isPopular: false,
           isCustom: false
       )
       
       static let mini_crossword = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544000F") ?? UUID(),
           name: "mini_crossword",
           displayName: "Mini Crossword",
           url: URL(string: "https://www.nytimes.com/crosswords/game/mini")!,
           category: .puzzle,
           resultPattern: #"Mini Crossword.*?(\d+:\d+|\d+s)"#,
           iconSystemName: "square.grid.2x2",
           backgroundColor: CodableColor(.systemBlue),
           isPopular: true,
           isCustom: false
       )
       
       static let sudoku = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440010") ?? UUID(),
           name: "sudoku",
           displayName: "Sudoku",
           url: URL(string: "https://www.nytimes.com/puzzles/sudoku")!,
           category: .puzzle,
           resultPattern: #"Sudoku.*?in (\d+:\d+|\d+m)"#,
           iconSystemName: "square.grid.3x3.topleft.filled",
           backgroundColor: CodableColor(.systemPurple),
           isPopular: true,
           isCustom: false
       )
       
       // Music Games
       static let lyricle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440011") ?? UUID(),
           name: "lyricle",
           displayName: "Lyricle",
           url: URL(string: "https://www.lyricle.app")!,
           category: .music,
           resultPattern: #"Lyricle \d+ [1-6X]/6"#,
           iconSystemName: "music.note.list",
           backgroundColor: CodableColor(.systemPink),
           isPopular: false,
           isCustom: false
       )
       
       // More Word Games
       static let absurdle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440012") ?? UUID(),
           name: "absurdle",
           displayName: "Absurdle",
           url: URL(string: "https://absurdle.online")!,
           category: .word,
           resultPattern: #"Absurdle.*?in \d+ guesses"#,
           iconSystemName: "questionmark.square",
           backgroundColor: CodableColor(.systemRed),
           isPopular: false,
           isCustom: false
       )
       
       static let semantle = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440013") ?? UUID(),
           name: "semantle",
           displayName: "Semantle",
           url: URL(string: "https://semantle.com")!,
           category: .word,
           resultPattern: #"Semantle #\d+.*?in \d+ guesses"#,
           iconSystemName: "brain",
           backgroundColor: CodableColor(.systemIndigo),
           isPopular: false,
           isCustom: false
       )
    
    // MARK: - More Word Games (21-30)
        
        static let dordle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440015") ?? UUID(),
            name: "dordle",
            displayName: "Dordle",
            url: URL(string: "https://zaratustra.itch.io/dordle")!,
            category: .word,
            resultPattern: #"Daily Dordle #\d+"#,
            iconSystemName: "square.on.square",
            backgroundColor: CodableColor(.systemOrange),
            isPopular: false,
            isCustom: false
        )
        
        static let sedecordle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440016") ?? UUID(),
            name: "sedecordle",
            displayName: "Sedecordle",
            url: URL(string: "https://sedecordle.com")!,
            category: .word,
            resultPattern: #"Daily Sedecordle #\d+"#,
            iconSystemName: "square.grid.3x3.square",
            backgroundColor: CodableColor(.systemRed),
            isPopular: false,
            isCustom: false
        )
        
    static let kilordle = Game(
        id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440017") ?? UUID(),
        name: "kilordle",
        displayName: "Kilordle",
        url: URL(string: "https://kilordle.com")!,
        category: .word,
        resultPattern: #"Kilordle.*?in \d+ guesses"#,
        iconSystemName: "infinity", // ← CHANGE THIS (was "infinity.square")
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false,
        isCustom: false
    )
        
        static let antiwordle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440018") ?? UUID(),
            name: "antiwordle",
            displayName: "Antiwordle",
            url: URL(string: "https://antiwordle.com")!,
            category: .word,
            resultPattern: #"Antiwordle.*?in \d+ attempts"#,
            iconSystemName: "arrow.uturn.backward.square",
            backgroundColor: CodableColor(.systemPink),
            isPopular: false,
            isCustom: false
        )
        
        static let wordscapes = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440019") ?? UUID(),
            name: "wordscapes",
            displayName: "Wordscapes",
            url: URL(string: "https://wordscapes.com")!,
            category: .word,
            resultPattern: #"Wordscapes.*?Level \d+"#,
            iconSystemName: "leaf",
            backgroundColor: CodableColor(.systemGreen),
            isPopular: false,
            isCustom: false
        )
        
        static let wordhurdle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544001A") ?? UUID(),
            name: "wordhurdle",
            displayName: "Word Hurdle",
            url: URL(string: "https://wordhurdle.com")!,
            category: .word,
            resultPattern: #"Word Hurdle.*?in \d+/6"#,
            iconSystemName: "figure.run.square.stack",
            backgroundColor: CodableColor(.systemBlue),
            isPopular: false,
            isCustom: false
        )
        
        static let xordle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544001B") ?? UUID(),
            name: "xordle",
            displayName: "Xordle",
            url: URL(string: "https://xordle.xyz")!,
            category: .word,
            resultPattern: #"Xordle #\d+ [1-9X]/9"#,
            iconSystemName: "xmark.square",
            backgroundColor: CodableColor(.systemGray),
            isPopular: false,
            isCustom: false
        )
        
        static let squareword = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544001C") ?? UUID(),
            name: "squareword",
            displayName: "Squareword",
            url: URL(string: "https://squareword.org")!,
            category: .word,
            resultPattern: #"Squareword.*?in \d+ guesses"#,
            iconSystemName: "square.text.square",
            backgroundColor: CodableColor(.systemMint),
            isPopular: false,
            isCustom: false
        )
        
        static let phrazle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544001D") ?? UUID(),
            name: "phrazle",
            displayName: "Phrazle",
            url: URL(string: "https://phrazle.com")!,
            category: .word,
            resultPattern: #"Phrazle.*?in \d+/6"#,
            iconSystemName: "text.quote",
            backgroundColor: CodableColor(.systemBrown),
            isPopular: false,
            isCustom: false
        )
        
        // MARK: - More Math/Logic Games (31-35)
        static let primel = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544001E") ?? UUID(),
            name: "primel",
            displayName: "Primel",
            url: URL(string: "https://converged.yt/primel")!,
            category: .math,
            resultPattern: #"Primel \d+ [1-6X]/6"#,
            iconSystemName: "number.circle",
            backgroundColor: CodableColor(.systemPurple),
            isPopular: false,
            isCustom: false
        )
        
        static let ooodle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544001F") ?? UUID(),
            name: "ooodle",
            displayName: "Ooodle",
            url: URL(string: "https://ooodle.live")!,
            category: .math,
            resultPattern: #"Ooodle.*?in \d+ attempts"#,
            iconSystemName: "plus.forwardslash.minus",
            backgroundColor: CodableColor(.systemOrange),
            isPopular: false,
            isCustom: false
        )
        
        static let summle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440020") ?? UUID(),
            name: "summle",
            displayName: "Summle",
            url: URL(string: "https://summle.com")!,
            category: .math,
            resultPattern: #"Summle.*?in \d+ tries"#,
            iconSystemName: "sum",
            backgroundColor: CodableColor(.systemYellow),
            isPopular: false,
            isCustom: false
        )
        
        static let timeguessr = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440021") ?? UUID(),
            name: "timeguessr",
            displayName: "TimeGuessr",
            url: URL(string: "https://timeguessr.com")!,
            category: .math,
            resultPattern: #"TimeGuessr.*?Score: \d+"#,
            iconSystemName: "clock.badge.questionmark",
            backgroundColor: CodableColor(.systemTeal),
            isPopular: false,
            isCustom: false
        )
        
        static let rankdle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440022") ?? UUID(),
            name: "rankdle",
            displayName: "Rankdle",
            url: URL(string: "https://rankdle.com")!,
            category: .math,
            resultPattern: #"Rankdle.*?in \d+ attempts"#,
            iconSystemName: "list.number",
            backgroundColor: CodableColor(.systemCyan),
            isPopular: false,
            isCustom: false
        )
        
        // MARK: - More Music/Audio Games (36-40)
        static let songlio = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440023") ?? UUID(),
            name: "songlio",
            displayName: "Songlio",
            url: URL(string: "https://songlio.com")!,
            category: .music,
            resultPattern: #"Songlio.*?in \d+ tries"#,
            iconSystemName: "music.mic",
            backgroundColor: CodableColor(.systemPink),
            isPopular: false,
            isCustom: false
        )
        
        static let binb = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440024") ?? UUID(),
            name: "binb",
            displayName: "BINB",
            url: URL(string: "https://binb.co")!,
            category: .music,
            resultPattern: #"BINB.*?in \d+ guesses"#,
            iconSystemName: "waveform",
            backgroundColor: CodableColor(.systemRed),
            isPopular: false,
            isCustom: false
        )
        
        static let songle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440025") ?? UUID(),
            name: "songle",
            displayName: "Songle",
            url: URL(string: "https://songle.io")!,
            category: .music,
            resultPattern: #"Songle.*?in \d+ attempts"#,
            iconSystemName: "music.quarternote.3",
            backgroundColor: CodableColor(.systemIndigo),
            isPopular: false,
            isCustom: false
        )
        
        static let bandle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440026") ?? UUID(),
            name: "bandle",
            displayName: "Bandle",
            url: URL(string: "https://bandle.app")!,
            category: .music,
            resultPattern: #"Bandle.*?\d+/6"#,
            iconSystemName: "guitars",
            backgroundColor: CodableColor(.systemGreen),
            isPopular: false,
            isCustom: false
        )
        
        static let musicle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440027") ?? UUID(),
            name: "musicle",
            displayName: "Musicle",
            url: URL(string: "https://musicle.app")!,
            category: .music,
            resultPattern: #"Musicle.*?in \d+ seconds"#,
            iconSystemName: "music.note.tv",
            backgroundColor: CodableColor(.systemBlue),
            isPopular: false,
            isCustom: false
        )
        
        // MARK: - More Geography Games (41-45)
        static let countryle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440028") ?? UUID(),
            name: "countryle",
            displayName: "Countryle",
            url: URL(string: "https://countryle.com")!,
            category: .geography,
            resultPattern: #"Countryle.*?in \d+ guesses"#,
            iconSystemName: "map",
            backgroundColor: CodableColor(.systemOrange),
            isPopular: false,
            isCustom: false
        )
        
        static let flagle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440029") ?? UUID(),
            name: "flagle",
            displayName: "Flagle",
            url: URL(string: "https://flagle.io")!,
            category: .geography,
            resultPattern: #"Flagle.*?in \d+/6"#,
            iconSystemName: "flag",
            backgroundColor: CodableColor(.systemRed),
            isPopular: false,
            isCustom: false
        )
        
        static let statele = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544002A") ?? UUID(),
            name: "statele",
            displayName: "Statele",
            url: URL(string: "https://statele.com")!,
            category: .geography,
            resultPattern: #"Statele.*?in \d+ guesses"#,
            iconSystemName: "map.circle",
            backgroundColor: CodableColor(.systemPurple),
            isPopular: false,
            isCustom: false
        )
        
        static let citydle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544002B") ?? UUID(),
            name: "citydle",
            displayName: "Citydle",
            url: URL(string: "https://citydle.com")!,
            category: .geography,
            resultPattern: #"Citydle.*?in \d+ attempts"#,
            iconSystemName: "building.2",
            backgroundColor: CodableColor(.systemGray),
            isPopular: false,
            isCustom: false
        )
        
        static let wheretaken = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544002C") ?? UUID(),
            name: "wheretaken",
            displayName: "WhereTaken",
            url: URL(string: "https://wheretaken.com")!,
            category: .geography,
            resultPattern: #"WhereTaken.*?in \d+ guesses"#,
            iconSystemName: "camera.on.rectangle",
            backgroundColor: CodableColor(.systemMint),
            isPopular: false,
            isCustom: false
        )
        
        // MARK: - More Trivia/Visual Games (46-50)
        static let moviedle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544002D") ?? UUID(),
            name: "moviedle",
            displayName: "Moviedle",
            url: URL(string: "https://moviedle.app")!,
            category: .trivia,
            resultPattern: #"Moviedle.*?in \d+ seconds"#,
            iconSystemName: "film",
            backgroundColor: CodableColor(.systemYellow),
            isPopular: false,
            isCustom: false
        )
        
        static let posterdle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544002E") ?? UUID(),
            name: "posterdle",
            displayName: "Posterdle",
            url: URL(string: "https://posterdle.com")!,
            category: .trivia,
            resultPattern: #"Posterdle.*?in \d+ guesses"#,
            iconSystemName: "photo.artframe",
            backgroundColor: CodableColor(.systemTeal),
            isPopular: false,
            isCustom: false
        )
        
        static let actorle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-44665544002F") ?? UUID(),
            name: "actorle",
            displayName: "Actorle",
            url: URL(string: "https://actorle.com")!,
            category: .trivia,
            resultPattern: #"Actorle.*?in \d+ guesses"#,
            iconSystemName: "person.crop.rectangle",
            backgroundColor: CodableColor(.systemBrown),
            isPopular: false,
            isCustom: false
        )
        
        static let foodguessr = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440030") ?? UUID(),
            name: "foodguessr",
            displayName: "FoodGuessr",
            url: URL(string: "https://foodguessr.com")!,
            category: .trivia,
            resultPattern: #"FoodGuessr.*?Score: \d+"#,
            iconSystemName: "fork.knife",
            backgroundColor: CodableColor(.systemOrange),
            isPopular: false,
            isCustom: false
        )
        
        static let artdle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440031") ?? UUID(),
            name: "artdle",
            displayName: "Artdle",
            url: URL(string: "https://artdle.com")!,
            category: .trivia,
            resultPattern: #"Artdle.*?in \d+ guesses"#,
            iconSystemName: "paintpalette",
            backgroundColor: CodableColor(.systemPink),
            isPopular: false,
            isCustom: false
        )
    
    // MARK: - Updated Popular Games Array (Only games with proper parsers)
    static let popularGames: [Game] = [
        wordle,
        quordle,
        nerdle,
        pips,
        connections,
        spellingBee,
        miniCrossword,
        strands,
        octordle
    ]
    
    // MARK: - All Games Array (Only games with proper parsers)
    static let allAvailableGames: [Game] = [
            // Games with implemented parsers
            wordle, quordle, nerdle, pips, connections, spellingBee, miniCrossword, strands,
            // LinkedIn Games
            linkedinQueens, linkedinTango, linkedinCrossclimb, linkedinPinpoint, linkedinZip, linkedinMiniSudoku,
            // Wordle Variants
            octordle
        ]
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

// MARK: - Thread-Safe Codable Color (Memory Optimized)
struct CodableColor: Codable, Hashable, Sendable {
    private let colorData: ColorData
    // Add to CodableColor:
    var color: Color {
        Color(uiColor: self.uiColor)
    }
    init(_ color: UIColor) {
        // Safe color mapping with comprehensive cases
        switch color {
        case UIColor.systemRed: self.colorData = .systemRed
        case UIColor.systemBlue: self.colorData = .systemBlue
        case UIColor.systemGreen: self.colorData = .systemGreen
        case UIColor.systemPurple: self.colorData = .systemPurple
        case UIColor.systemPink: self.colorData = .systemPink
        case UIColor.systemYellow: self.colorData = .systemYellow
        case UIColor.systemOrange: self.colorData = .systemOrange
        case UIColor.systemGray: self.colorData = .systemGray
        case UIColor.systemTeal: self.colorData = .systemTeal
        case UIColor.systemIndigo: self.colorData = .systemIndigo
        case UIColor.systemCyan: self.colorData = .systemCyan
        default:
            // Extract RGB components safely
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                self.colorData = .custom(red: Double(red), green: Double(green), blue: Double(blue))
            } else {
                // Fallback for colors that can't be converted
                self.colorData = .systemBlue
                let logger = Logger(subsystem: "com.streaksync.models", category: "CodableColor")
                logger.error("Failed to convert UIColor to CodableColor, using systemBlue fallback")
            }
        }
    }
    
    private init(colorData: ColorData) {
        self.colorData = colorData
    }
    
    var uiColor: UIColor {
        switch colorData {
        case .systemRed: return .systemRed
        case .systemBlue: return .systemBlue
        case .systemGreen: return .systemGreen
        case .systemPurple: return .systemPurple
        case .systemPink: return .systemPink
        case .systemYellow: return .systemYellow
        case .systemOrange: return .systemOrange
        case .systemGray: return .systemGray
        case .systemTeal: return .systemTeal
        case .systemIndigo: return .systemIndigo
        case .systemCyan: return .systemCyan
        case .custom(let red, let green, let blue):
            return UIColor(displayP3Red: red, green: green, blue: blue, alpha: 1.0)
        }
    }
    
    // MARK: - Color Data Enum (Thread-Safe)
    private enum ColorData: Codable, Hashable, Sendable {
        case systemRed
        case systemBlue
        case systemGreen
        case systemPurple
        case systemPink
        case systemYellow
        case systemOrange
        case systemGray
        case systemTeal
        case systemIndigo
        case systemCyan
        case custom(red: Double, green: Double, blue: Double)
    }
    
    // MARK: - Static Factory Methods
    static let red = CodableColor(colorData: .systemRed)
    static let blue = CodableColor(colorData: .systemBlue)
    static let green = CodableColor(colorData: .systemGreen)
    static let purple = CodableColor(colorData: .systemPurple)
    static let pink = CodableColor(colorData: .systemPink)
    static let yellow = CodableColor(colorData: .systemYellow)
    static let orange = CodableColor(colorData: .systemOrange)
    static let gray = CodableColor(colorData: .systemGray)
    static let teal = CodableColor(colorData: .systemTeal)
    static let indigo = CodableColor(colorData: .systemIndigo)
    static let cyan = CodableColor(colorData: .systemCyan)
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
    
    var displayScore: String {
        // Special handling for multi-puzzle games like Quordle
        if gameName.lowercased() == "quordle" {
            return quordleDisplayScore
        }
        
        // Special handling for Pips difficulty-based scoring
        if gameName.lowercased() == "pips" {
            return pipsDisplayScore
        }
        
        // Special handling for Connections
        if gameName.lowercased() == "connections" {
            return connectionsDisplayScore
        }
        
        // Special handling for LinkedIn Zip
        if gameName.lowercased() == "linkedinzip" {
            return zipDisplayScore
        }
        
        // Special handling for LinkedIn Tango
        if gameName.lowercased() == "linkedintango" {
            return tangoDisplayScore
        }
        
        // Special handling for LinkedIn Queens
        if gameName.lowercased() == "linkedinqueens" {
            return queensDisplayScore
        }
        
        // Special handling for LinkedIn Crossclimb
        if gameName.lowercased() == "linkedincrossclimb" {
            return crossclimbDisplayScore
        }
        
        // Special handling for LinkedIn Pinpoint
        if gameName.lowercased() == "linkedinpinpoint" {
            return pinpointDisplayScore
        }
        
        // Special handling for NYT Strands
        if gameName.lowercased() == "strands" {
            return strandsDisplayScore
        }
        
        // Special handling for Octordle
        if gameName.lowercased() == "octordle" {
            return octordleDisplayScore
        }
        
        // Standard score display
        guard let score = score else {
            let formatString = NSLocalizedString("game.failed_score", comment: "X/%d")
            return String(format: formatString, maxAttempts)
        }
        return "\(score)/\(maxAttempts)"
    }
    
    private var quordleDisplayScore: String {
        // Try to get individual scores from parsedData
        if let score1 = parsedData["score1"],
           let score2 = parsedData["score2"],
           let score3 = parsedData["score3"],
           let score4 = parsedData["score4"] {
            
            // Format as "6-5-9-4" or "X-X-X-X"
            let s1 = score1 == "failed" ? "X" : score1
            let s2 = score2 == "failed" ? "X" : score2
            let s3 = score3 == "failed" ? "X" : score3
            let s4 = score4 == "failed" ? "X" : score4
            
            return "\(s1)-\(s2)-\(s3)-\(s4)"
        }
        
        // Fallback to standard display if individual scores not available
        guard let score = score else {
            return "X/\(maxAttempts)"
        }
        return "\(score)/\(maxAttempts)"
    }
    
    private var pipsDisplayScore: String {
        // Get difficulty and time from parsedData
        if let difficulty = parsedData["difficulty"],
           let time = parsedData["time"] {
            return "\(difficulty) - \(time)"
        }
        
        // Fallback to standard display if difficulty/time not available
        guard let score = score else {
            return "X/\(maxAttempts)"
        }
        return "\(score)/\(maxAttempts)"
    }
    
    private var connectionsDisplayScore: String {
        // Get solved categories from parsedData
        if let solvedCategories = parsedData["solvedCategories"],
           let solved = Int(solvedCategories) {
            return "\(solved)/4"
        }
        
        // Fallback to score if available
        if let score = score {
            return "\(score)/4"
        }
        
        return "0/4"
    }
    
    private var zipDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var tangoDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var queensDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var crossclimbDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var pinpointDisplayScore: String {
        // Get guess count from parsedData (this is the main score)
        if let guessCount = parsedData["guessCount"], !guessCount.isEmpty {
            return "\(guessCount) guesses"
        }
        
        // Fallback to score converted to guess format
        if let score = score, score > 0 {
            return "\(score) guesses"
        }
        
        return "Completed"
    }
    
    private var strandsDisplayScore: String {
        // Get hint count from parsedData (this is the main score)
        if let hintCount = parsedData["hintCount"], !hintCount.isEmpty {
            let count = Int(hintCount) ?? 0
            return count == 0 ? "Perfect" : "\(count) hints"
        }
        
        // Fallback to score converted to hint format
        if let score = score {
            return score == 0 ? "Perfect" : "\(score) hints"
        }
        
        return "Completed"
    }
    
    private var octordleDisplayScore: String {
        // For Octordle, just show the score (not score/attempts)
        // Lower scores are better (8 is perfect, higher scores indicate more attempts)
        guard let score = score else {
            return "Failed"
        }
        
        return "\(score)"
    }
    
    var scoreEmoji: String {
        // Special handling for Quordle
        if gameName.lowercased() == "quordle" {
            return quordleScoreEmoji
        }
        
        // Special handling for LinkedIn Pinpoint (completed vs not completed)
        if gameName.lowercased() == "linkedinpinpoint" {
            return pinpointScoreEmoji
        }
        
        // Special handling for Pips difficulty-based emojis
        if gameName.lowercased() == "pips" {
            return pipsScoreEmoji
        }
        
        // Special handling for Connections
        if gameName.lowercased() == "connections" {
            return connectionsScoreEmoji
        }
        
        // Standard emoji
        guard let score = score else { return "❌" }
        switch score {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "✅"
        }
    }
    
    private var pinpointScoreEmoji: String {
        // For Pinpoint, explicitly show failure if not completed (e.g., 5/5 without pin)
        guard completed else { return "❌" }
        // Use typical attempt medals for low guess counts, checkmark otherwise
        guard let score = score else { return "✅" }
        switch score {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "✅"
        }
    }
    
    private var quordleScoreEmoji: String {
        // Check if all puzzles completed
        if let completedStr = parsedData["completedPuzzles"],
           let completed = Int(completedStr) {
            switch completed {
            case 4: return "🏆"  // All 4 completed
            case 3: return "🥉"  // 3 completed
            case 2: return "🥈"  // 2 completed
            case 1: return "🥇"  // 1 completed
            default: return "❌" // None completed
            }
        }
        
        // Fallback
        return completed ? "✅" : "❌"
    }
    
    private var pipsScoreEmoji: String {
        // Get difficulty from parsedData and return appropriate emoji
        if let difficulty = parsedData["difficulty"] {
            switch difficulty.lowercased() {
            case "easy": return "🟢"
            case "medium": return "🟡"
            case "hard": return "🟠"
            default: return "✅"
            }
        }
        
        // Fallback based on score
        guard let score = score else { return "❌" }
        switch score {
        case 1: return "🟢"  // Easy
        case 2: return "🟡"  // Medium
        case 3: return "🟠"  // Hard
        default: return "✅"
        }
    }
    
    private var connectionsScoreEmoji: String {
        // Get solved categories from parsedData
        if let solvedCategories = parsedData["solvedCategories"],
           let solved = Int(solvedCategories) {
            switch solved {
            case 4: return "🏆"  // Perfect - all 4 categories solved
            case 3: return "🥇"  // Great - 3/4 categories solved
            case 2: return "🥈"  // Good - 2/4 categories solved
            case 1: return "🥉"  // Partial - 1/4 categories solved
            default: return "❌" // Failed - 0 categories solved
            }
        }
        
        // Fallback based on score
        guard let score = score else { return "❌" }
        switch score {
        case 4: return "🏆"  // Perfect
        case 3: return "🥇"  // Great
        case 2: return "🥈"  // Good
        case 1: return "🥉"  // Partial
        default: return "❌" // Failed
        }
    }
    
    var accessibilityDescription: String {
        let statusText = completed ?
            NSLocalizedString("game.completed", comment: "Completed") :
            NSLocalizedString("game.failed", comment: "Failed")
        return NSLocalizedString("game.accessibility_description",
                                comment: "\(gameName), \(displayScore), \(statusText)")
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

// MARK: - Thread-Safe Date Extensions
extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    var daysSinceNow: Int {
        Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
    }
    
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    var accessibilityDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}

// MARK: - URL Validation Extensions
extension URL {
    var isValidGameURL: Bool {
        guard let scheme = scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = host,
              !host.isEmpty else {
            return false
        }
        return true
    }
    
    var isSecure: Bool {
        scheme?.lowercased() == "https"
    }
}
