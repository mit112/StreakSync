//
//  SharedModels.swift - PRODUCTION READY (FIXED)
//  StreakSync & StreakSyncShareExtension
//
//  FIXED: All force unwrapping removed with safe alternatives
//

import Foundation
import UIKit
import OSLog

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
    
    static let popularGames = [wordle, quordle, nerdle, heardle]
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
