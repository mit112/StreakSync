//
//  GameResultParser.swift
//  StreakSync
//
//  Simple game result parser for manual entry
//

import Foundation

// MARK: - Game Result Parser
struct GameResultParser {
    
    func parse(_ text: String, for game: Game) throws -> GameResult {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch game.name.lowercased() {
        case "wordle":
            return try parseWordle(cleanText, gameId: game.id)
        case "quordle":
            return try parseQuordle(cleanText, gameId: game.id)
        case "nerdle":
            return try parseNerdle(cleanText, gameId: game.id)
        case "heardle":
            return try parseHeardle(cleanText, gameId: game.id)
        default:
            return try parseGeneric(cleanText, game: game)
        }
    }
    
    // MARK: - Wordle Parser
    private func parseWordle(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Wordle 1,492 3/6" or "Wordle 1492 X/6"
        let pattern = #"Wordle\s+(\d+(?:,\d+)*)\s+([X1-6])/6"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text),
              let scoreRange = Range(match.range(at: 2), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange]).replacingOccurrences(of: ",", with: "")
        let scoreString = String(text[scoreRange])
        
        let score = scoreString == "X" ? nil : Int(scoreString)
        let completed = scoreString != "X"
        
        return GameResult(
            gameId: gameId,
            gameName: "wordle",
            date: Date(),
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: text,
            parsedData: ["puzzleNumber": puzzleNumber]
        )
    }
    
    // MARK: - Quordle Parser
    private func parseQuordle(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Daily Quordle 723" followed by scores like "4️⃣5️⃣\n6️⃣7️⃣"
        let pattern = #"Daily Quordle\s+(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let hasScores = text.contains("⃣") || text.contains("🟥")
        let completed = hasScores && !text.contains("🟥")
        
        return GameResult(
            gameId: gameId,
            gameName: "quordle",
            date: Date(),
            score: completed ? 1 : nil,
            maxAttempts: 9,
            completed: completed,
            sharedText: text,
            parsedData: ["puzzleNumber": puzzleNumber]
        )
    }
    
    // MARK: - Nerdle Parser
    private func parseNerdle(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "nerdlegame 728 3/6"
        let pattern = #"nerdlegame\s+(\d+)\s+([X1-6])/6"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text),
              let scoreRange = Range(match.range(at: 2), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let scoreString = String(text[scoreRange])
        
        let score = scoreString == "X" ? nil : Int(scoreString)
        let completed = scoreString != "X"
        
        return GameResult(
            gameId: gameId,
            gameName: "nerdle",
            date: Date(),
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: text,
            parsedData: ["puzzleNumber": puzzleNumber]
        )
    }
    
    // MARK: - Heardle Parser
    private func parseHeardle(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "#Heardle #123"
        let pattern = #"#?Heardle\s+#?(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let hasEmojis = text.contains("🔊") || text.contains("🎵")
        
        return GameResult(
            gameId: gameId,
            gameName: "heardle",
            date: Date(),
            score: hasEmojis ? 1 : nil,
            maxAttempts: 6,
            completed: hasEmojis,
            sharedText: text,
            parsedData: ["puzzleNumber": puzzleNumber]
        )
    }
    
    // MARK: - Generic Parser
    private func parseGeneric(_ text: String, game: Game) throws -> GameResult {
        // Look for common patterns like "3/6", "X/6"
        let scorePattern = #"([X\d])/(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: scorePattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let scoreRange = Range(match.range(at: 1), in: text),
              let maxRange = Range(match.range(at: 2), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let scoreString = String(text[scoreRange])
        let maxString = String(text[maxRange])
        
        let score = scoreString == "X" ? nil : Int(scoreString)
        let maxAttempts = Int(maxString) ?? 6
        let completed = scoreString != "X"
        
        return GameResult(
            gameId: game.id,
            gameName: game.name.lowercased(),
            date: Date(),
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: text,
            parsedData: ["source": "manual"]
        )
    }
}

// MARK: - Parsing Error
enum ParsingError: LocalizedError {
    case invalidFormat
    case unsupportedGame
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Could not parse the game result. Please check the format."
        case .unsupportedGame:
            return "This game is not supported yet."
        }
    }
}
