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
    
    // MARK: - Pips Parser
    private func parsePips(_ text: String, gameId: UUID) throws -> GameResult {
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
            score: difficultyScore, // Use difficulty as score
            maxAttempts: 3, // Easy, Medium, Hard
            completed: true, // If we can parse it, it was completed
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "difficulty": difficulty,
                "time": timeString,
                "totalSeconds": "\(totalSeconds)"
            ]
        )
    }
    
    // MARK: - NYT Connections Parser
    private func parseConnections(_ text: String, gameId: UUID) throws -> GameResult {
        // Check if this looks like a Connections result
        guard text.contains("Connections") && text.contains("Puzzle #") else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number using a simple approach
        let puzzleNumberPattern = #"Puzzle #(\d+)"#
        guard let puzzleRegex = try? NSRegularExpression(pattern: puzzleNumberPattern, options: .caseInsensitive),
              let puzzleMatch = puzzleRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(puzzleMatch.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract emoji grid - split by lines and find emoji-only lines
        let lines = text.components(separatedBy: .newlines)
        var emojiRows: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Check if line contains only emoji squares (4 emojis)
            if trimmedLine.count == 4 && 
               trimmedLine.allSatisfy({ "🟩🟨🟦🟪".contains($0) }) {
                emojiRows.append(trimmedLine)
            }
        }
        
        // Parse the emoji grid to extract game statistics
        let gameStats = parseConnectionsEmojiGrid(emojiRows.joined(separator: " "))
        
        return GameResult(
            gameId: gameId,
            gameName: "connections",
            date: Date(),
            score: gameStats.solvedCategories, // Always include score (0-4)
            maxAttempts: 4, // 4 categories total
            completed: gameStats.completed, // Only true if all 4 categories solved
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "totalGuesses": "\(gameStats.totalGuesses)",
                "solvedCategories": "\(gameStats.solvedCategories)",
                "strikes": "\(gameStats.strikes)",
                "emojiGrid": emojiRows.joined(separator: " ")
            ]
        )
    }
    
    // MARK: - Connections Emoji Grid Parser Helper
    private func parseConnectionsEmojiGrid(_ emojiGrid: String) -> (totalGuesses: Int, solvedCategories: Int, strikes: Int, completed: Bool) {
        // Split by spaces to get individual emoji rows
        let emojiRows = emojiGrid.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .filter { $0.contains("🟩") || $0.contains("🟨") || $0.contains("🟦") || $0.contains("🟪") }
        
        var solvedCategories = 0
        var strikes = 0
        
        for row in emojiRows {
            // Check if this row has 4 identical emojis (solved category)
            let emojis = Array(row)
            if emojis.count == 4 {
                // Check if all 4 emojis are the same
                let firstEmoji = emojis[0]
                let allSame = emojis.allSatisfy { $0 == firstEmoji }
                
                if allSame {
                    solvedCategories += 1
                } else {
                    strikes += 1
                }
            } else {
                // Invalid row format, count as strike
                strikes += 1
            }
        }
        
        let totalGuesses = emojiRows.count
        let completed = solvedCategories == 4
        
        return (totalGuesses: totalGuesses, solvedCategories: solvedCategories, strikes: strikes, completed: completed)
    }
    
    // MARK: - NYT Spelling Bee Parser
    private func parseSpellingBee(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Spelling Bee\nScore: 150\nWords: 25\nRank: Genius"
        let pattern = #"Spelling Bee[\s\S]*?Score:\s*(\d+)[\s\S]*?Words:\s*(\d+)[\s\S]*?Rank:\s*([A-Za-z\s]+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let scoreRange = Range(match.range(at: 1), in: text),
              let wordsRange = Range(match.range(at: 2), in: text),
              let rankRange = Range(match.range(at: 3), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let scoreString = String(text[scoreRange])
        let wordsString = String(text[wordsRange])
        let rankString = String(text[rankRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let score = Int(scoreString) ?? 0
        let _ = Int(wordsString) ?? 0 // wordsFound - not used in current implementation
        
        // Determine completion based on rank (Genius and above are considered "completed")
        let completed = rankString.lowercased().contains("genius") || 
                       rankString.lowercased().contains("queen bee") ||
                       rankString.lowercased().contains("amazing")
        
        return GameResult(
            gameId: gameId,
            gameName: "spellingbee",
            date: Date(),
            score: score,
            maxAttempts: 1000, // High number since Spelling Bee has no fixed max
            completed: completed,
            sharedText: text,
            parsedData: [
                "score": scoreString,
                "wordsFound": wordsString,
                "rank": rankString
            ]
        )
    }
    
    // MARK: - NYT Mini Crossword Parser
    private func parseMiniCrossword(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Mini Crossword\nCompleted in 2:30"
        let pattern = #"Mini Crossword[\s\S]*?Completed in (\d+:\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let timeRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let completionTime = String(text[timeRange])
        
        // Parse completion time (MM:SS format)
        let timeComponents = completionTime.split(separator: ":")
        let totalSeconds: Int
        if timeComponents.count == 2,
           let minutes = Int(timeComponents[0]),
           let seconds = Int(timeComponents[1]) {
            totalSeconds = minutes * 60 + seconds
        } else {
            totalSeconds = 0
        }
        
        // Mini Crossword is always completed if we can parse the time
        return GameResult(
            gameId: gameId,
            gameName: "minicrossword",
            date: Date(),
            score: totalSeconds, // Use completion time as score (lower is better)
            maxAttempts: 600, // 10 minutes max (reasonable limit)
            completed: true,
            sharedText: text,
            parsedData: [
                "completionTime": completionTime,
                "totalSeconds": "\(totalSeconds)"
            ]
        )
    }
    
    // MARK: - NYT Strands Parser
    private func parseStrands(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Strands results - actual shared format
        // Format: "Strands #580\n\"Bring it home\"\n💡🔵🔵💡\n🔵🟡🔵🔵\n🔵"
        let pattern = #"Strands\s+#(\d+)"#
        
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
        
        // Extract theme (optional)
        var theme = ""
        let themePattern = #""([^"]+)""#
        if let themeRegex = try? NSRegularExpression(pattern: themePattern, options: .caseInsensitive),
           let themeMatch = themeRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
           themeMatch.range(at: 1).location != NSNotFound,
           let themeRange = Range(themeMatch.range(at: 1), in: text) {
            theme = String(text[themeRange])
        }
        
        // Count hint emojis (💡) to determine hint count
        let hintCount = text.components(separatedBy: "💡").count - 1
        
        // For Strands, score is the number of hints used (lower is better)
        // Perfect score = 0 hints, Hinted = 1+ hints
        let score = hintCount
        
        return GameResult(
            gameId: gameId,
            gameName: "strands",
            date: Date(),
            score: score,
            maxAttempts: 10, // Reasonable upper limit for hints
            completed: true, // Strands is always completed (no failure state)
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "hintCount": "\(hintCount)",
                "theme": theme,
                "gameType": "word_puzzle",
                "displayScore": hintCount == 0 ? "Perfect" : "\(hintCount) hints"
            ]
        )
    }
    
    // MARK: - LinkedIn Games Parsers
    
    // MARK: - LinkedIn Queens Parser
    private func parseLinkedInQueens(_ text: String, gameId: UUID) throws -> GameResult {
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
    private func parseLinkedInTango(_ text: String, gameId: UUID) throws -> GameResult {
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
    private func parseLinkedInCrossclimb(_ text: String, gameId: UUID) throws -> GameResult {
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
    private func parseLinkedInPinpoint(_ text: String, gameId: UUID) throws -> GameResult {
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
    private func parseLinkedInZip(_ text: String, gameId: UUID) throws -> GameResult {
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
    private func parseLinkedInMiniSudoku(_ text: String, gameId: UUID) throws -> GameResult {
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
    
    // MARK: - Octordle Parser
    private func parseOctordle(_ text: String, gameId: UUID) throws -> GameResult {
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
        let isCompleted = !hasFailedWords
        
        return GameResult(
            gameId: gameId,
            gameName: "octordle",
            date: Date(),
            score: mainScore, // Use the actual score from "Score: XX" line
            maxAttempts: mainScore, // For Octordle, maxAttempts = score (attempts don't matter)
            completed: isCompleted, // Only completed if NO red squares (🟥) appear
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
    private func parseOctordleEmoji(_ emoji: String) -> Int {
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
        
        // For generic games, we can't calculate the actual date, so use current date
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
