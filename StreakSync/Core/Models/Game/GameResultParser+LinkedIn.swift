//
//  GameResultParser+LinkedIn.swift
//  StreakSync
//
//  LinkedIn game parsers: Queens, Tango, Crossclimb, Pinpoint, Zip, Mini Sudoku
//

import Foundation

extension GameResultParser {

    // MARK: - LinkedIn Games Parsers
    
    // MARK: - LinkedIn Queens Parser
    func parseLinkedInQueens(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Queens results with time
        // Format: "Queens #522\n1:11 👑\nlnkd.in/queens."
        let pattern = #"Queens\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
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
        
        // Extract time
        var timeString: String?
        if match.range(at: 2).location != NSNotFound {
            if let timeRange = Range(match.range(at: 2), in: text) {
                timeString = String(text[timeRange])
            }
        }
        
        // For Queens, score is the actual time in seconds
        var score = 0
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }
        
        return GameResult(
            gameId: gameId,
            gameName: "linkedinqueens",
            date: Date(),
            score: score,
            maxAttempts: 0, // Queens doesn't have attempts/backtracks
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "logic_puzzle",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Tango Parser
    func parseLinkedInTango(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Tango results with time
        // Format: "Tango #362\n1:10 🌗\nlnkd.in/tango."
        let pattern = #"Tango\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
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
        
        // Extract time
        var timeString: String?
        if match.range(at: 2).location != NSNotFound {
            if let timeRange = Range(match.range(at: 2), in: text) {
                timeString = String(text[timeRange])
            }
        }
        
        // For Tango, score is the actual time in seconds
        var score = 0
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }
        
        return GameResult(
            gameId: gameId,
            gameName: "linkedintango",
            date: Date(),
            score: score,
            maxAttempts: 0, // Tango doesn't have attempts/backtracks
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "logic_puzzle",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Crossclimb Parser
    func parseLinkedInCrossclimb(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Crossclimb results with time
        // Format: "Crossclimb #522\n2:08 🪜\n🏅 I'm on a 94-day win streak!\nlnkd.in/crossclimb."
        let pattern = #"Crossclimb\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
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
        
        // Extract time
        var timeString: String?
        if match.range(at: 2).location != NSNotFound {
            if let timeRange = Range(match.range(at: 2), in: text) {
                timeString = String(text[timeRange])
            }
        }
        
        // For Crossclimb, score is the actual time in seconds
        var score = 0
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }
        
        return GameResult(
            gameId: gameId,
            gameName: "linkedincrossclimb",
            date: Date(),
            score: score,
            maxAttempts: 0, // Crossclimb doesn't have attempts/backtracks
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "word_association",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Pinpoint Parser
    func parseLinkedInPinpoint(_ text: String, gameId: UUID) throws -> GameResult {
        // Updated patterns to handle multiple Pinpoint share formats:
        // Format 1 (Original): "Pinpoint #522 | 5 guesses\n1️⃣  | 1% match\n2️⃣  | 5% match\n3️⃣  | 82% match\n4️⃣  | 28% match\n5️⃣  | 100% match 📌\nlnkd.in/pinpoint."
        // Format 2 (New): "Pinpoint #542\n🤔 📌 ⬜ ⬜ ⬜ (2/5)\n🏅 I'm in the Top 25% of my connections today!\nlnkd.in/pinpoint."
        // Format 3 (New): "Pinpoint #542\n🤔 📌 ⬜ ⬜ ⬜ (2/5)\n🏅 I'm in the Top 10% of all players today!\nlnkd.in/pinpoint."
        
        // First try the new emoji-based format (flexible):
        // Accept any emoji sequence before the parenthesized score, e.g.:
        // "🤔 🤔 🤔 🤔 📌 (5/5)" or "🤔 📌 ⬜ ⬜ ⬜ (2/5)"
        let emojiPattern = #"Pinpoint\s+#(\d+)[\s\S]*?(?:[🤔📌⬜⬛🟩🟨🟧🟦🟪🟫⚫⚪\s]+)?\((\d+)/(\d+)\)"#
        
        if let emojiRegex = try? NSRegularExpression(pattern: emojiPattern, options: .caseInsensitive),
           let emojiMatch = emojiRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
            
            // Extract puzzle number
            guard emojiMatch.range(at: 1).location != NSNotFound,
                  let puzzleRange = Range(emojiMatch.range(at: 1), in: text) else {
                throw ParsingError.invalidFormat
            }
            let puzzleNumber = String(text[puzzleRange])
            
            // Extract guess count from (X/Y) format
            guard emojiMatch.range(at: 2).location != NSNotFound,
                  let guessRange = Range(emojiMatch.range(at: 2), in: text),
                  let maxRange = Range(emojiMatch.range(at: 3), in: text) else {
                throw ParsingError.invalidFormat
            }
            
            let guessCount = Int(String(text[guessRange])) ?? 0
            let maxAttempts = Int(String(text[maxRange])) ?? 5
            
            // Check for completion - look for 📌 emoji in the pattern
            let isCompleted = text.contains("📌")
            
            return GameResult(
                gameId: gameId,
                gameName: "linkedinpinpoint",
                date: Date(),
                score: guessCount,
                maxAttempts: maxAttempts,
                completed: isCompleted,
                sharedText: text,
                parsedData: [
                    "puzzleNumber": puzzleNumber,
                    "guessCount": "\(guessCount)",
                    "gameType": "word_association",
                    "displayScore": "\(guessCount) guesses",
                    "shareFormat": "emoji_based"
                ]
            )
        }
        
        // Fallback to original format parsing
        let originalPattern = #"Pinpoint\s+#(\d+)(?:\s*\|\s*(\d+)\s+guesses)?[\s\S]*?(?:(\d+)\s+guesses)?"#
        
        guard let regex = try? NSRegularExpression(pattern: originalPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract guess count (try both formats)
        var guessCount = 0
        if match.range(at: 2).location != NSNotFound,
           let guessRange = Range(match.range(at: 2), in: text) {
            guessCount = Int(String(text[guessRange])) ?? 0
        } else if match.range(at: 3).location != NSNotFound,
                  let guessRange = Range(match.range(at: 3), in: text) {
            guessCount = Int(String(text[guessRange])) ?? 0
        }
        
        // If no explicit guess count, count the emoji lines
        if guessCount == 0 {
            let emojiPattern = #"(\d+️⃣)"#
            if let emojiRegex = try? NSRegularExpression(pattern: emojiPattern, options: .caseInsensitive) {
                let emojiMatches = emojiRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                guessCount = emojiMatches.count
            }
        }
        
        // Check for completion - look for 100% match or 📌 emoji
        let isCompleted = text.contains("100% match") || text.contains("📌")
        
        // For Pinpoint, score is the number of guesses (lower is better)
        let score = guessCount > 0 ? guessCount : 1
        
        return GameResult(
            gameId: gameId,
            gameName: "linkedinpinpoint",
            date: Date(),
            score: score,
            maxAttempts: 5, // Pinpoint typically allows up to 5 guesses
            completed: isCompleted,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "guessCount": "\(guessCount)",
                "gameType": "word_association",
                "displayScore": guessCount > 0 ? "\(guessCount) guesses" : "Completed",
                "shareFormat": "original"
            ]
        )
    }
    
    // MARK: - LinkedIn Zip Parser
    func parseLinkedInZip(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Zip results with time and optional backtrack info
        // Format 1: "Zip #201 | 0:23 🏁\nWith 1 backtrack 🛑\nlnkd.in/zip."
        // Format 2: "Zip #201\n0:37 🏁\nlnkd.in/zip."
        let pattern = #"Zip\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?[\s\S]*?(?:With\s+(\d+)\s+backtrack)?"#
        
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
        
        // Extract time (now in group 2)
        var timeString: String?
        if match.range(at: 2).location != NSNotFound {
            if let timeRange = Range(match.range(at: 2), in: text) {
                timeString = String(text[timeRange])
            }
        }
        
        // Extract backtrack count (now in group 3)
        var backtrackCount = "0"
        if match.range(at: 3).location != NSNotFound {
            if let backtrackRange = Range(match.range(at: 3), in: text) {
                backtrackCount = String(text[backtrackRange])
            }
        }
        
        // For Zip, score is the actual time in seconds
        var score = 0
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }
        
        return GameResult(
            gameId: gameId,
            gameName: "linkedinzip",
            date: Date(),
            score: score,
            maxAttempts: Int(backtrackCount) ?? 0, // Use backtrack count as maxAttempts
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "backtrackCount": backtrackCount,
                "gameType": "connectivity_puzzle",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Mini Sudoku Parser
    func parseLinkedInMiniSudoku(_ text: String, gameId: UUID) throws -> GameResult {
        // Flexible pattern for Mini Sudoku puzzle results
        // Expected formats: "Mini Sudoku puzzle completed", "Mini Sudoku puzzle #123", etc.
        let pattern = #"Mini Sudoku.*?puzzle.*?(?:#(\d+))?.*?(?:completed|solved|finished)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            throw ParsingError.invalidFormat
        }
        
        var puzzleNumber = "1" // Default puzzle number
        if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
            if let puzzleRange = Range(match.range(at: 1), in: text) {
                puzzleNumber = String(text[puzzleRange])
            }
        }
        
        // Mini Sudoku is typically completed if we can parse it
        return GameResult(
            gameId: gameId,
            gameName: "linkedinminisudoku",
            date: Date(),
            score: 1, // Completed
            maxAttempts: 1,
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "gameType": "sudoku"
            ]
        )
    }
    
}
