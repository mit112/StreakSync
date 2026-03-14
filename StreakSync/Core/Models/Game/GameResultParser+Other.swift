//
//  GameResultParser+Other.swift
//  StreakSync
//
//  Other game parsers: Quordle, Nerdle, Pips, Octordle
//

import Foundation

extension GameResultParser {

    // MARK: - Quordle Parser
    func parseQuordle(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Daily Quordle 1346" followed by scores like "6️⃣5️⃣\n9️⃣4️⃣"
        let pattern = #"Daily Quordle\s+(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange])
        
        // Parse emoji scores (0️⃣-9️⃣) and failures (🟥)
        let scores = extractQuordleScores(from: text)
        let failedPuzzles = scores.filter { $0 == -1 }.count
        let completedPuzzles = scores.filter { $0 > 0 }.count
        
        // Calculate average score for completed puzzles (or nil if any failed)
        let averageScore: Int?
        if failedPuzzles > 0 {
            averageScore = nil
        } else if completedPuzzles > 0 {
            let validScores = scores.filter { $0 > 0 }
            averageScore = validScores.reduce(0, +) / validScores.count
        } else {
            averageScore = nil
        }
        
        let completed = failedPuzzles == 0 && completedPuzzles == 4
        
        var parsedData: [String: String] = ["puzzleNumber": puzzleNumber]
        if scores.count >= 4 {
            parsedData["score1"] = scores[0] > 0 ? "\(scores[0])" : "failed"
            parsedData["score2"] = scores[1] > 0 ? "\(scores[1])" : "failed"
            parsedData["score3"] = scores[2] > 0 ? "\(scores[2])" : "failed"
            parsedData["score4"] = scores[3] > 0 ? "\(scores[3])" : "failed"
            parsedData["completedPuzzles"] = "\(completedPuzzles)"
            parsedData["failedPuzzles"] = "\(failedPuzzles)"
        }
        
        return GameResult(
            gameId: gameId,
            gameName: "quordle",
            date: Date(),
            score: averageScore,
            maxAttempts: 9,
            completed: completed,
            sharedText: text,
            parsedData: parsedData
        )
    }
    
    // MARK: - Quordle Helper
    private func extractQuordleScores(from text: String) -> [Int] {
        // Map emojis to their numeric values
        let emojiMap: [String: Int] = [
            "0️⃣": 0, "1️⃣": 1, "2️⃣": 2, "3️⃣": 3, "4️⃣": 4,
            "5️⃣": 5, "6️⃣": 6, "7️⃣": 7, "8️⃣": 8, "9️⃣": 9,
            "🟥": -1
        ]
        
        var scores: [Int] = []
        
        // Use regex to find all number emojis and failure markers in order
        let pattern = "(0️⃣|1️⃣|2️⃣|3️⃣|4️⃣|5️⃣|6️⃣|7️⃣|8️⃣|9️⃣|🟥)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return scores
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                let emoji = String(text[range])
                if let value = emojiMap[emoji] {
                    scores.append(value)
                }
            }
        }
        
        return scores
    }
    
    // MARK: - Nerdle Parser
    func parseNerdle(_ text: String, gameId: UUID) throws -> GameResult {
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
    
    // MARK: - Pips Parser
    func parsePips(_ text: String, gameId: UUID) throws -> GameResult {
        // More flexible pattern that handles both formats:
        // 1. "Pips #46 Easy 🟢" followed by "1:03" (with emoji)
        // 2. "Pips #46 Easy" followed by "0:54" (without emoji)
        let pattern = #"Pips #(\d+) (Easy|Medium|Hard)(?:\s*[🟢🟡🟠🟤⚫⚪])?[\s\S]*?(\d{1,2}:\d{2})"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text),
              let difficultyRange = Range(match.range(at: 2), in: text),
              let timeRange = Range(match.range(at: 3), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let difficulty = String(text[difficultyRange])
        let timeString = String(text[timeRange])
        
        // Parse time (MM:SS format)
        let timeComponents = timeString.split(separator: ":")
        let totalSeconds: Int
        if timeComponents.count == 2,
           let minutes = Int(timeComponents[0]),
           let seconds = Int(timeComponents[1]) {
            totalSeconds = minutes * 60 + seconds
        } else {
            totalSeconds = 0
        }
        
        // Map difficulty to numeric value for scoring
        let difficultyScore: Int
        switch difficulty.lowercased() {
        case "easy": difficultyScore = 1
        case "medium": difficultyScore = 2
        case "hard": difficultyScore = 3
        default: difficultyScore = 1
        }
        
        return GameResult(
            gameId: gameId,
            gameName: "pips",
            date: Date(),
            score: totalSeconds,
            maxAttempts: 600, // 10 min reasonable max for time-based scoring
            completed: true, // If we can parse it, it was completed
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "difficulty": difficulty,
                "time": timeString,
                "totalSeconds": "\(totalSeconds)",
                "difficultyLevel": "\(difficultyScore)"
            ]
        )
    }
    

    func parseOctordle(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Daily Octordle #1349\n8️⃣4️⃣\n5️⃣🕛\n🕚🔟\n6️⃣7️⃣\nScore: 63"
        let pattern = #"Daily Octordle #(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract score from "Score: XX" line
        var totalScore = 0
        let scorePattern = #"Score:\s*(\d+)"#
        if let scoreRegex = try? NSRegularExpression(pattern: scorePattern, options: .caseInsensitive),
           let scoreMatch = scoreRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
           scoreMatch.range(at: 1).location != NSNotFound,
           let scoreRange = Range(scoreMatch.range(at: 1), in: text) {
            totalScore = Int(String(text[scoreRange])) ?? 0
        } else {
            // If no score line found, calculate from emoji grid
            // This handles cases where users only paste the emoji grid without the score line
            totalScore = calculateScoreFromEmojiGrid(text)
        }
        
        // Parse individual word scores from emoji grid to check for failures
        var hasFailedWords = false
        var completedWords = 0
        var failedWords = 0
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip empty lines and header lines
            if trimmedLine.isEmpty || trimmedLine.contains("Daily Octordle") || trimmedLine.contains("Score:") {
                continue
            }
            
            // Parse emoji line (e.g., "8️⃣4️⃣" or "🟥🟥" or "🟥6️⃣")
            let emojis = Array(trimmedLine)
            for emoji in emojis {
                let score = parseOctordleEmoji(String(emoji))
                if score > 0 {
                    if score == 13 { // Failed word (🟥)
                        hasFailedWords = true
                        failedWords += 1
                    } else {
                        completedWords += 1
                    }
                }
            }
        }
        
        // Use the actual score from "Score: XX" line as the main score
        let mainScore = totalScore

        // Determine completion status - only completed if NO red squares (🟥) appear
        // A completed game with score 0 is invalid (lowerAttempts requires score >= 1)
        let isCompleted = !hasFailedWords && mainScore > 0

        return GameResult(
            gameId: gameId,
            gameName: "octordle",
            date: Date(),
            score: isCompleted ? mainScore : nil,
            maxAttempts: 104, // Theoretical max: 13 guesses × 8 words
            completed: isCompleted,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "totalScore": "\(totalScore)",
                "completedWords": "\(completedWords)",
                "failedWords": "\(failedWords)",
                "completionRate": "\(completedWords)/8",
                "hasFailedWords": "\(hasFailedWords)",
                "gameType": "word_variant"
            ]
        )
    }
    
    // Helper function to parse Octordle emojis
    func parseOctordleEmoji(_ emoji: String) -> Int {
        switch emoji {
        case "1️⃣": return 1
        case "2️⃣": return 2
        case "3️⃣": return 3
        case "4️⃣": return 4
        case "5️⃣": return 5
        case "6️⃣": return 6
        case "7️⃣": return 7
        case "8️⃣": return 8
        case "9️⃣": return 9
        case "🔟": return 10
        case "🕚": return 11
        case "🕛": return 12
        case "🟥": return 13 // Failed word (treated as 13 for scoring)
        default: return 0
        }
    }
    
    // Helper function to calculate score from emoji grid when Score line is missing
    private func calculateScoreFromEmojiGrid(_ text: String) -> Int {
        var totalScore = 0
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip empty lines and header lines
            if trimmedLine.isEmpty || trimmedLine.contains("Daily Octordle") || trimmedLine.contains("Score:") {
                continue
            }
            
            // Parse emoji line (e.g., "8️⃣4️⃣" or "🟥🟥" or "🟥6️⃣")
            let emojis = Array(trimmedLine)
            for emoji in emojis {
                let score = parseOctordleEmoji(String(emoji))
                if score > 0 {
                    totalScore += score
                }
            }
        }
        
        return totalScore
    }
    
}
