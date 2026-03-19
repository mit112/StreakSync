//
//  GameDefinitions.swift
//  StreakSync
//
//  All static Game instances, IDs, URLs, and catalog arrays.
//  Extracted from SharedModels.swift for maintainability.
//

import Foundation
import UIKit

extension Game {
    // MARK: - Safe UUID Initializer
    /// Returns a UUID from a known-valid string. Triggers assertionFailure in debug builds if the
    /// string is malformed — catches typos at dev time rather than silently producing random IDs.
    static func safeUUID(_ string: String) -> UUID {
        guard let uuid = UUID(uuidString: string) else {
            assertionFailure("Invalid UUID string: \(string)")
            return UUID()
        }
        return uuid
    }

    // MARK: - Static Game IDs (Guaranteed Valid)
    private enum GameIDs {
        static let wordle = Game.safeUUID("550e8400-e29b-41d4-a716-446655440000")
        static let quordle = Game.safeUUID("550e8400-e29b-41d4-a716-446655440001")
        static let nerdle = Game.safeUUID("550e8400-e29b-41d4-a716-446655440002")
        static let connections = Game.safeUUID("550e8400-e29b-41d4-a716-446655440003")
        static let spellingBee = Game.safeUUID("550e8400-e29b-41d4-a716-446655440004")
        static let miniCrossword = Game.safeUUID("550e8400-e29b-41d4-a716-446655440005")
        static let strands = Game.safeUUID("550e8400-e29b-41d4-a716-446655440007")
        // LinkedIn Games
        static let linkedinQueens = Game.safeUUID("550e8400-e29b-41d4-a716-446655440100")
        static let linkedinTango = Game.safeUUID("550e8400-e29b-41d4-a716-446655440101")
        static let linkedinCrossclimb = Game.safeUUID("550e8400-e29b-41d4-a716-446655440102")
        static let linkedinPinpoint = Game.safeUUID("550e8400-e29b-41d4-a716-446655440103")
        static let linkedinZip = Game.safeUUID("550e8400-e29b-41d4-a716-446655440104")
        static let linkedinMiniSudoku = Game.safeUUID("550e8400-e29b-41d4-a716-446655440105")
        // Wordle Variants
        static let octordle = Game.safeUUID("550e8400-e29b-41d4-a716-446655440200")
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
        resultPattern: #"(Daily Quordle \d+|Weekly Quordle Challenge \d+)"#,
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
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440006"),
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
        scoringModel: .higherIsBetter // Share format has no consistent time data; score=1 means completed
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
