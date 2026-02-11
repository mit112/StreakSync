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
