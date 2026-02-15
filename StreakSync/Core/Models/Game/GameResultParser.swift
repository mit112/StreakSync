//
//  GameResultParser.swift
//  StreakSync
//
//  Game result parser — routes to per-category extensions
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
        case "pips":
            return try parsePips(cleanText, gameId: game.id)
        case "connections":
            return try parseConnections(cleanText, gameId: game.id)
        case "spellingbee":
            return try parseSpellingBee(cleanText, gameId: game.id)
        case "minicrossword":
            return try parseMiniCrossword(cleanText, gameId: game.id)
        case "strands":
            return try parseStrands(cleanText, gameId: game.id)
        // LinkedIn Games
        case "linkedinqueens":
            return try parseLinkedInQueens(cleanText, gameId: game.id)
        case "linkedintango":
            return try parseLinkedInTango(cleanText, gameId: game.id)
        case "linkedincrossclimb":
            return try parseLinkedInCrossclimb(cleanText, gameId: game.id)
        case "linkedinpinpoint":
            return try parseLinkedInPinpoint(cleanText, gameId: game.id)
        case "linkedinzip":
            return try parseLinkedInZip(cleanText, gameId: game.id)
        case "linkedinminisudoku":
            return try parseLinkedInMiniSudoku(cleanText, gameId: game.id)
        case "octordle":
            return try parseOctordle(cleanText, gameId: game.id)
        default:
            return try parseGeneric(cleanText, game: game)
        }
    }

    private func parseGeneric(_ text: String, game: Game) throws -> GameResult {
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
