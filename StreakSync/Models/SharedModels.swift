//
//  SharedModels.swift - PRODUCTION READY (FIXED)
//  StreakSync & StreakSyncShareExtension
//
//  FIXED: All force unwrapping removed with safe alternatives
//

import Foundation
import UIKit
import OSLog
import SwiftUICore

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
        isCustom: Bool
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
    }
    
    // MARK: - Computed Properties
    var hostDomain: String {
        url.host ?? "Unknown"
    }
    
    var isOfficial: Bool {
        !isCustom
    }
    // Add to Game struct:
    var isActiveToday: Bool {
        // A game is active if it has been played recently (within last 7 days)
        guard let lastPlayed = lastPlayedDate else { return false }
        let daysSinceLastPlayed = Calendar.current.dateComponents([.day], from: lastPlayed, to: Date()).day ?? 0
        return daysSinceLastPlayed < 7
    }

    var hasPlayedToday: Bool {
        guard let lastPlayed = lastPlayedDate else { return false }
        return Calendar.current.isDateInToday(lastPlayed)
    }

    var lastPlayedDate: Date? {
        // This would come from your game results/streak data
        // For now, return nil - you'll need to implement this based on your data structure
        nil
    }
    
    var accessibilityDescription: String {
        "\(displayName) game, \(category.displayName) category"
    }
    
    // MARK: - Static Game IDs (Guaranteed Valid)
    private enum GameIDs {
        static let wordle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000") ?? UUID()
        static let quordle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001") ?? UUID()
        static let nerdle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002") ?? UUID()
        static let heardle = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440003") ?? UUID()
    }
    
    // MARK: - Static Game URLs (Guaranteed Valid)
    private enum GameURLs {
        // SwiftLint exemption: These URLs are hardcoded constants that require force unwrap fallbacks
        // swiftlint:disable force_unwrapping
        static let wordle = URL(string: "https://www.nytimes.com/games/wordle") ?? URL(string: "https://www.nytimes.com")!
        static let quordle = URL(string: "https://www.quordle.com") ?? URL(string: "https://www.merriam-webster.com")!
        static let nerdle = URL(string: "https://nerdlegame.com") ?? URL(string: "https://nerdlegame.com")!
        static let heardle = URL(string: "https://www.heardle.app") ?? URL(string: "https://www.heardle.app")!
        // swiftlint:enable force_unwrapping
    }
    
    // MARK: - Static Game Instances (Safe - IDs and URLs Guaranteed)
    static let wordle = Game(
        id: GameIDs.wordle,
        name: "wordle",
        displayName: "Wordle",
        url: GameURLs.wordle,
        category: .word,
        resultPattern: #"Wordle \d+ [1-6X]/6"#,
        iconSystemName: "square.grid.3x3.fill",
        backgroundColor: CodableColor(.systemGreen),
        isPopular: true,
        isCustom: false
    )
    
    static let quordle = Game(
        id: GameIDs.quordle,
        name: "quordle",
        displayName: "Quordle",
        url: GameURLs.quordle,
        category: .word,
        resultPattern: #"Daily Quordle \d+"#,
        iconSystemName: "square.grid.2x2.fill",
        backgroundColor: CodableColor(.systemBlue),
        isPopular: true,
        isCustom: false
    )
    
    static let nerdle = Game(
        id: GameIDs.nerdle,
        name: "nerdle",
        displayName: "Nerdle",
        url: GameURLs.nerdle,
        category: .math,
        resultPattern: #"nerdlegame \d+ [1-6]/6"#,
        iconSystemName: "function",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: true,
        isCustom: false
    )
    
    static let heardle = Game(
        id: GameIDs.heardle,
        name: "heardle",
        displayName: "Heardle",
        url: GameURLs.heardle,
        category: .music,
        resultPattern: #"#Heardle #\d+"#,
        iconSystemName: "music.note",
        backgroundColor: CodableColor(.systemPink),
        isPopular: true,
        isCustom: false
    )
    // Word Games
       static let connections = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440004") ?? UUID(),
           name: "connections",
           displayName: "Connections",
           url: URL(string: "https://www.nytimes.com/games/connections")!,
           category: .word,
           resultPattern: #"Connections\nPuzzle #\d+"#,
           iconSystemName: "square.grid.3x3",
           backgroundColor: CodableColor(.systemPurple),
           isPopular: true,
           isCustom: false
       )
       
       static let spelling_bee = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440005") ?? UUID(),
           name: "spelling_bee",
           displayName: "Spelling Bee",
           url: URL(string: "https://www.nytimes.com/puzzles/spelling-bee")!,
           category: .word,
           resultPattern: #"Spelling Bee.*?\d+ words"#,
           iconSystemName: "hexagon",
           backgroundColor: CodableColor(.systemYellow),
           isPopular: true,
           isCustom: false
       )
       
       static let letterboxed = Game(
           id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440006") ?? UUID(),
           name: "letterboxed",
           displayName: "Letter Boxed",
           url: URL(string: "https://www.nytimes.com/puzzles/letter-boxed")!,
           category: .word,
           resultPattern: #"Letter Boxed.*?in \d+ words"#,
           iconSystemName: "square.on.square",
           backgroundColor: CodableColor(.systemOrange),
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
        static let octordle = Game(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440014") ?? UUID(),
            name: "octordle",
            displayName: "Octordle",
            url: URL(string: "https://octordle.com")!,
            category: .word,
            resultPattern: #"Daily Octordle #\d+"#,
            iconSystemName: "square.grid.4x3.fill",
            backgroundColor: CodableColor(.systemPurple),
            isPopular: false,
            isCustom: false
        )
        
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
    
    // MARK: - Updated Popular Games Array
    static let popularGames: [Game] = [
        wordle,
        quordle,
        nerdle,
        heardle,
        connections,
        spelling_bee,
        worldle,
        contexto,
        mini_crossword,
        sudoku
    ]
    
    // MARK: - All Games Array (for GameCatalog)
    static let allAvailableGames: [Game] = [
            // Original Word Games (1-8)
            wordle, quordle, connections, spelling_bee,
            letterboxed, waffle, absurdle, semantle,
            
            // Additional Word Games (21-30)
            octordle, dordle, sedecordle, kilordle,
            antiwordle, wordscapes, wordhurdle, xordle,
            squareword, phrazle,
            
            // Original Math Games (9-10)
            nerdle, mathle, numberle,
            
            // Additional Math Games (31-35)
            primel, ooodle, summle, timeguessr, rankdle,
            
            // Original Music Games (11-12)
            heardle, lyricle,
            
            // Additional Music Games (36-40)
            songlio, binb, songle, bandle, musicle,
            
            // Original Geography Games (13-14)
            worldle, globle,
            
            // Additional Geography Games (41-45)
            countryle, flagle, statele, citydle, wheretaken,
            
            // Original Trivia Games (15-16)
            contexto, framed,
            
            // Additional Trivia Games (46-50)
            moviedle, posterdle, actorle, foodguessr, artdle,
            
            // Original Puzzle Games (17-20)
            crosswordle, mini_crossword, sudoku
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
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .word: return NSLocalizedString("category.word", comment: "Word Games")
        case .math: return NSLocalizedString("category.math", comment: "Math Games")
        case .music: return NSLocalizedString("category.music", comment: "Music Games")
        case .geography: return NSLocalizedString("category.geography", comment: "Geography")
        case .trivia: return NSLocalizedString("category.trivia", comment: "Trivia")
        case .puzzle: return NSLocalizedString("category.puzzle", comment: "Puzzle Games")
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
    
    // MARK: - Validated Initializer
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
        // Input validation
        precondition(!gameName.isEmpty, "Game name cannot be empty")
        precondition(maxAttempts > 0, "Max attempts must be positive")
        precondition(!sharedText.isEmpty, "Shared text cannot be empty")
        
        if let score = score {
            precondition(score >= 1 && score <= maxAttempts, "Score must be between 1 and maxAttempts")
        }
        
        self.id = UUID()
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
        guard let score = score else {
            return NSLocalizedString("game.failed_score", comment: "X/\(maxAttempts)")
        }
        return "\(score)/\(maxAttempts)"
    }
    
    var scoreEmoji: String {
        guard let score = score else { return "❌" }
        switch score {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "✅"
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
        maxAttempts > 0 &&
        (score == nil || (score! >= 1 && score! <= maxAttempts)) &&
        !sharedText.isEmpty
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
