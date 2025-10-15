//
//  ShareViewController.swift - ULTRA SIMPLE VERSION
//  StreakSyncShareExtension
//

import UIKit
import UniformTypeIdentifiers
import Foundation

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Simple UI
        view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Processing..."
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Process the shared content
        processContent()
    }
    
    private func processContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showResult("No content")
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let text = item as? String {
                        self?.processText(text)
                    } else {
                        self?.showResult("Couldn't process text")
                    }
                }
            }
        } else {
            showResult("Unsupported content type")
        }
    }
    
    private func processText(_ text: String) {
        print("🔍 SHARE EXTENSION: Received text: '\(text)'")
        
        // Game detection and parsing
        if text.contains("Pips #") {
            print("🔍 SHARE EXTENSION: Detected Pips result")
            if let result = parsePips(text) {
                saveResult(result)
                showResult("Pips result saved!")
            } else {
                showResult("Couldn't parse Pips result")
            }
        } else if text.contains("Daily Quordle") {
            print("🔍 SHARE EXTENSION: Detected Quordle result")
            if let result = parseQuordle(text) {
                saveResult(result)
                showResult("Quordle result saved!")
            } else {
                showResult("Couldn't parse Quordle result")
            }
        } else if text.contains("Wordle") {
            print("🔍 SHARE EXTENSION: Detected Wordle result")
            if let result = parseWordle(text) {
                saveResult(result)
                showResult("Wordle result saved!")
            } else {
                showResult("Couldn't parse Wordle result")
            }
        } else if text.contains("nerdlegame") {
            print("🔍 SHARE EXTENSION: Detected Nerdle result")
            if let result = parseNerdle(text) {
                saveResult(result)
                showResult("Nerdle result saved!")
            } else {
                showResult("Couldn't parse Nerdle result")
            }
        } else if text.contains("Connections") && text.contains("Puzzle #") {
            print("🔍 SHARE EXTENSION: Detected Connections result")
            if let result = parseConnections(text) {
                saveResult(result)
                showResult("Connections result saved!")
            } else {
                showResult("Couldn't parse Connections result")
            }
        } else if text.contains("Strands #") {
            print("🔍 SHARE EXTENSION: Detected Strands result")
            if let result = parseStrands(text) {
                saveResult(result)
                showResult("Strands result saved!")
            } else {
                showResult("Couldn't parse Strands result")
            }
        } else if text.contains("Queens #") {
            print("🔍 SHARE EXTENSION: Detected LinkedIn Queens result")
            if let result = parseLinkedInQueens(text) {
                saveResult(result)
                showResult("LinkedIn Queens result saved!")
            } else {
                showResult("Couldn't parse LinkedIn Queens result")
            }
        } else if text.contains("Tango #") {
            print("🔍 SHARE EXTENSION: Detected LinkedIn Tango result")
            if let result = parseLinkedInTango(text) {
                saveResult(result)
                showResult("LinkedIn Tango result saved!")
            } else {
                showResult("Couldn't parse LinkedIn Tango result")
            }
        } else if text.contains("Crossclimb #") {
            print("🔍 SHARE EXTENSION: Detected LinkedIn Crossclimb result")
            if let result = parseLinkedInCrossclimb(text) {
                saveResult(result)
                showResult("LinkedIn Crossclimb result saved!")
            } else {
                showResult("Couldn't parse LinkedIn Crossclimb result")
            }
        } else if text.contains("Pinpoint #") {
            print("🔍 SHARE EXTENSION: Detected LinkedIn Pinpoint result")
            if let result = parseLinkedInPinpoint(text) {
                saveResult(result)
                showResult("LinkedIn Pinpoint result saved!")
            } else {
                showResult("Couldn't parse LinkedIn Pinpoint result")
            }
        } else if text.contains("Zip #") {
            print("🔍 SHARE EXTENSION: Detected LinkedIn Zip result")
            if let result = parseLinkedInZip(text) {
                saveResult(result)
                showResult("LinkedIn Zip result saved!")
            } else {
                showResult("Couldn't parse LinkedIn Zip result")
            }
        } else if text.contains("Mini Sudoku #") {
            print("🔍 SHARE EXTENSION: Detected LinkedIn Mini Sudoku result")
            if let result = parseLinkedInMiniSudoku(text) {
                saveResult(result)
                showResult("LinkedIn Mini Sudoku result saved!")
            } else {
                showResult("Couldn't parse LinkedIn Mini Sudoku result")
            }
        } else if text.contains("Daily Octordle") {
            print("🔍 SHARE EXTENSION: Detected Octordle result")
            if let result = parseOctordle(text) {
                saveResult(result)
                showResult("Octordle result saved!")
            } else {
                showResult("Couldn't parse Octordle result")
            }
        } else {
            print("🔍 SHARE EXTENSION: Unknown game format")
            showResult("Unknown game format")
        }
    }
    
    private func parsePips(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing Pips text: '\(text)'")
        
        // Clean text to remove emoji interference (same as main app)
        let cleanText = text.replacingOccurrences(of: "🟢", with: "")
            .replacingOccurrences(of: "🟡", with: "")
            .replacingOccurrences(of: "🟠", with: "")
            .replacingOccurrences(of: "🟤", with: "")
            .replacingOccurrences(of: "⚫", with: "")
            .replacingOccurrences(of: "⚪", with: "")
        
        print("🔍 SHARE EXTENSION: Cleaned text: '\(cleanText)'")
        
        // Use the same robust pattern as main app that handles multi-line format
        // Pattern: "Pips #47 Easy" followed by "0:24" (handles both single and multi-line)
        let pattern = #"Pips #(\d+) (Easy|Medium|Hard)[\s\S]*?(\d{1,2}:\d{2})"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            print("🔍 SHARE EXTENSION: Failed to create regex")
            return nil
        }
        
        let range = NSRange(location: 0, length: cleanText.count)
        guard let match = regex.firstMatch(in: cleanText, options: [], range: range) else {
            print("🔍 SHARE EXTENSION: No regex match in cleaned text")
            // Try original text as fallback
            let originalRange = NSRange(location: 0, length: text.count)
            guard let originalMatch = regex.firstMatch(in: text, options: [], range: originalRange) else {
                print("🔍 SHARE EXTENSION: No regex match in original text either")
                return nil
            }
            
            // Use original match
            guard let puzzleRange = Range(originalMatch.range(at: 1), in: text),
                  let difficultyRange = Range(originalMatch.range(at: 2), in: text),
                  let timeRange = Range(originalMatch.range(at: 3), in: text) else {
                print("🔍 SHARE EXTENSION: Could not extract ranges from original match")
                return nil
            }
            
            let puzzleNumber = String(text[puzzleRange])
            let difficulty = String(text[difficultyRange])
            let timeString = String(text[timeRange])
            
            print("🔍 SHARE EXTENSION: Extracted from original text - Puzzle: \(puzzleNumber), Difficulty: \(difficulty), Time: \(timeString)")
            
            return createPipsResult(puzzleNumber: puzzleNumber, difficulty: difficulty, timeString: timeString, text: text)
        }
        
        // Extract from cleaned text
        guard let puzzleRange = Range(match.range(at: 1), in: cleanText),
              let difficultyRange = Range(match.range(at: 2), in: cleanText),
              let timeRange = Range(match.range(at: 3), in: cleanText) else {
            print("🔍 SHARE EXTENSION: Could not extract ranges from cleaned match")
            return nil
        }
        
        let puzzleNumber = String(cleanText[puzzleRange])
        let difficulty = String(cleanText[difficultyRange])
        let timeString = String(cleanText[timeRange])
        
        print("🔍 SHARE EXTENSION: Extracted from cleaned text - Puzzle: \(puzzleNumber), Difficulty: \(difficulty), Time: \(timeString)")
        
        return createPipsResult(puzzleNumber: puzzleNumber, difficulty: difficulty, timeString: timeString, text: text)
    }
    
    private func createPipsResult(puzzleNumber: String, difficulty: String, timeString: String, text: String) -> [String: Any] {
        // Parse time (MM:SS format) - same as main app
        let timeComponents = timeString.split(separator: ":")
        let totalSeconds: Int
        if timeComponents.count == 2,
           let minutes = Int(timeComponents[0]),
           let seconds = Int(timeComponents[1]) {
            totalSeconds = minutes * 60 + seconds
        } else {
            totalSeconds = 0
        }
        
        // Map difficulty to numeric value for scoring - same as main app
        let difficultyScore: Int
        switch difficulty.lowercased() {
        case "easy": difficultyScore = 1
        case "medium": difficultyScore = 2
        case "hard": difficultyScore = 3
        default: difficultyScore = 1
        }
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440006",
            "gameName": "pips",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": difficultyScore,
            "maxAttempts": 3,
            "completed": true,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "difficulty": difficulty,
                "time": timeString,
                "totalSeconds": "\(totalSeconds)",
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - Quordle Parser
    private func parseQuordle(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing Quordle text: '\(text)'")
        
        // Pattern: "Daily Quordle 1346" followed by scores like "6️⃣5️⃣\n9️⃣4️⃣"
        let pattern = #"Daily Quordle\s+(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Quordle pattern not found")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange])
        print("🔍 SHARE EXTENSION: Extracted puzzle number: \(puzzleNumber)")
        
        // Parse emoji scores (0️⃣-9️⃣) and failures (🟥)
        let scores = extractQuordleScores(from: text)
        print("🔍 SHARE EXTENSION: Extracted scores: \(scores)")
        
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
        parsedData["source"] = "shareExtension"
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440001", // Quordle game ID
            "gameName": "quordle",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": averageScore,
            "maxAttempts": 9,
            "completed": completed,
            "sharedText": text,
            "parsedData": parsedData
        ]
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
    
    // MARK: - Wordle Parser
    private func parseWordle(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing Wordle text: '\(text)'")
        
        // Pattern: "Wordle 1,492 3/6" or "Wordle 1492 X/6"
        let pattern = #"Wordle\s+(\d+(?:,\d+)*)\s+([X1-6])/6"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text),
              let scoreRange = Range(match.range(at: 2), in: text) else {
            print("🔍 SHARE EXTENSION: Wordle pattern not found")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange]).replacingOccurrences(of: ",", with: "")
        let scoreString = String(text[scoreRange])
        
        let score = scoreString == "X" ? nil : Int(scoreString)
        let completed = scoreString != "X"
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Score: \(scoreString), Completed: \(completed)")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440000", // Wordle game ID
            "gameName": "wordle",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": score,
            "maxAttempts": 6,
            "completed": completed,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - Nerdle Parser
    private func parseNerdle(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing Nerdle text: '\(text)'")
        
        // Pattern: "nerdlegame 728 3/6"
        let pattern = #"nerdlegame\s+(\d+)\s+([X1-6])/6"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text),
              let scoreRange = Range(match.range(at: 2), in: text) else {
            print("🔍 SHARE EXTENSION: Nerdle pattern not found")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let scoreString = String(text[scoreRange])
        
        let score = scoreString == "X" ? nil : Int(scoreString)
        let completed = scoreString != "X"
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Score: \(scoreString), Completed: \(completed)")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440002", // Nerdle game ID
            "gameName": "nerdle",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": score,
            "maxAttempts": 6,
            "completed": completed,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - NYT Connections Parser
    private func parseConnections(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing Connections text: '\(text)'")
        
        // Extract puzzle number using a simple approach
        let puzzleNumberPattern = #"Puzzle #(\d+)"#
        guard let puzzleRegex = try? NSRegularExpression(pattern: puzzleNumberPattern, options: .caseInsensitive),
              let puzzleMatch = puzzleRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(puzzleMatch.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Connections puzzle number not found")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange])
        print("🔍 SHARE EXTENSION: Extracted puzzle number: \(puzzleNumber)")
        
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
        
        print("🔍 SHARE EXTENSION: Found \(emojiRows.count) emoji rows")
        
        // Parse the emoji grid to extract game statistics
        let gameStats = parseConnectionsEmojiGrid(emojiRows.joined(separator: " "))
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440003", // Connections game ID
            "gameName": "connections",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": gameStats.solvedCategories > 0 ? gameStats.solvedCategories : nil, // Use nil for 0 categories
            "maxAttempts": 4, // 4 categories total
            "completed": gameStats.completed,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "totalGuesses": "\(gameStats.totalGuesses)",
                "solvedCategories": "\(gameStats.solvedCategories)",
                "strikes": "\(gameStats.strikes)",
                "emojiGrid": emojiRows.joined(separator: " "),
                "source": "shareExtension"
            ]
        ]
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
    
    // MARK: - NYT Strands Parser
    private func parseStrands(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing Strands text: '\(text)'")
        
        // Pattern for Strands results - actual shared format
        // Format: "Strands #580\n\"Bring it home\"\n💡🔵🔵💡\n🔵🟡🔵🔵\n🔵"
        let pattern = #"Strands\s+#(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: Strands pattern not found")
            return nil
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Could not extract puzzle number")
            return nil
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
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Theme: \(theme), Hints: \(hintCount)")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440007", // Strands game ID
            "gameName": "strands",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": hintCount,
            "maxAttempts": 10, // Reasonable upper limit for hints
            "completed": true, // Strands is always completed (no failure state)
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "hintCount": "\(hintCount)",
                "theme": theme,
                "gameType": "word_puzzle",
                "displayScore": hintCount == 0 ? "Perfect" : "\(hintCount) hints",
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - LinkedIn Games Parsers
    
    // MARK: - LinkedIn Queens Parser
    private func parseLinkedInQueens(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing LinkedIn Queens text: '\(text)'")
        
        // Pattern for Queens results with time
        // Format: "Queens #522\n1:11 👑\nlnkd.in/queens."
        let pattern = #"Queens\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: LinkedIn Queens pattern not found")
            return nil
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Could not extract puzzle number")
            return nil
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
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Time: \(timeString ?? "N/A")")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440100", // LinkedIn Queens game ID
            "gameName": "linkedinqueens",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": score,
            "maxAttempts": 0, // Queens doesn't have attempts/backtracks
            "completed": true,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "logic_puzzle",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed",
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - LinkedIn Tango Parser
    private func parseLinkedInTango(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing LinkedIn Tango text: '\(text)'")
        
        // Pattern for Tango results with time
        // Format: "Tango #362\n1:10 🌗\nlnkd.in/tango."
        let pattern = #"Tango\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: LinkedIn Tango pattern not found")
            return nil
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Could not extract puzzle number")
            return nil
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
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Time: \(timeString ?? "N/A")")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440101", // LinkedIn Tango game ID
            "gameName": "linkedintango",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": score,
            "maxAttempts": 0, // Tango doesn't have attempts/backtracks
            "completed": true,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "logic_puzzle",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed",
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - LinkedIn Crossclimb Parser
    private func parseLinkedInCrossclimb(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing LinkedIn Crossclimb text: '\(text)'")
        
        // Pattern for Crossclimb results with time
        // Format: "Crossclimb #522\n2:08 🪜\n🏅 I'm on a 94-day win streak!\nlnkd.in/crossclimb."
        let pattern = #"Crossclimb\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: LinkedIn Crossclimb pattern not found")
            return nil
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Could not extract puzzle number")
            return nil
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
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Time: \(timeString ?? "N/A")")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440102", // LinkedIn Crossclimb game ID
            "gameName": "linkedincrossclimb",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": score,
            "maxAttempts": 0, // Crossclimb doesn't have attempts/backtracks
            "completed": true,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "word_association",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed",
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - LinkedIn Pinpoint Parser
    private func parseLinkedInPinpoint(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing LinkedIn Pinpoint text: '\(text)'")
        
        // Pattern for Pinpoint results with guesses and match percentages
        // Format 1: "Pinpoint #522\n1️⃣  | 15% match\n2️⃣  | 1% match\n3️⃣  | 86% match\n4️⃣  | 75% match\n5️⃣  | 97% match\nlnkd.in/pinpoint."
        // Format 2: "Pinpoint #522 | 5 guesses\n1️⃣  | 1% match\n2️⃣  | 5% match\n3️⃣  | 82% match\n4️⃣  | 28% match\n5️⃣  | 100% match 📌\nlnkd.in/pinpoint."
        let pattern = #"Pinpoint\s+#(\d+)(?:\s*\|\s*(\d+)\s+guesses)?[\s\S]*?(?:(\d+)\s+guesses)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: LinkedIn Pinpoint pattern not found")
            return nil
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Could not extract puzzle number")
            return nil
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
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Guesses: \(guessCount), Completed: \(isCompleted)")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440103", // LinkedIn Pinpoint game ID
            "gameName": "linkedinpinpoint",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": score,
            "maxAttempts": 5, // Pinpoint typically allows up to 5 guesses
            "completed": isCompleted,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "guessCount": "\(guessCount)",
                "gameType": "word_association",
                "displayScore": guessCount > 0 ? "\(guessCount) guesses" : "Completed",
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - LinkedIn Zip Parser
    private func parseLinkedInZip(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing LinkedIn Zip text: '\(text)'")
        
        // Pattern for Zip results with time and optional backtrack info
        // Format 1: "Zip #201 | 0:23 🏁\nWith 1 backtrack 🛑\nlnkd.in/zip."
        // Format 2: "Zip #201\n0:37 🏁\nlnkd.in/zip."
        let pattern = #"Zip\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?[\s\S]*?(?:With\s+(\d+)\s+backtrack)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: LinkedIn Zip pattern not found")
            return nil
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Could not extract puzzle number")
            return nil
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
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Time: \(timeString ?? "N/A"), Backtrack: \(backtrackCount)")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440104", // LinkedIn Zip game ID
            "gameName": "linkedinzip",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": score,
            "maxAttempts": Int(backtrackCount) ?? 0, // Use backtrack count as maxAttempts
            "completed": true,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "backtrackCount": backtrackCount,
                "gameType": "connectivity_puzzle",
                "displayScore": timeString != nil ? "\(timeString!)" : "Completed",
                "source": "shareExtension"
            ]
        ]
    }
    
    // MARK: - LinkedIn Mini Sudoku Parser
    private func parseLinkedInMiniSudoku(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing LinkedIn Mini Sudoku text: '\(text)'")
        
        // Flexible pattern for Mini Sudoku puzzle results
        let pattern = #"Mini Sudoku.*?puzzle.*?(?:#(\d+))?.*?(?:completed|solved|finished)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: LinkedIn Mini Sudoku pattern not found")
            return nil
        }
        
        var puzzleNumber = "1" // Default puzzle number
        if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
            if let puzzleRange = Range(match.range(at: 1), in: text) {
                puzzleNumber = String(text[puzzleRange])
            }
        }
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber)")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440105", // LinkedIn Mini Sudoku game ID
            "gameName": "linkedinminisudoku",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": 1, // Completed
            "maxAttempts": 1,
            "completed": true,
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "gameType": "sudoku",
                "source": "shareExtension"
            ]
        ]
    }
    
    private func parseOctordle(_ text: String) -> [String: Any]? {
        print("🔍 SHARE EXTENSION: Parsing Octordle text: '\(text)'")
        print("🔍 SHARE EXTENSION: Text length: \(text.count)")
        
        // Pattern: "Daily Octordle #1349\n8️⃣4️⃣\n5️⃣🕛\n🕚🔟\n6️⃣7️⃣\nScore: 63"
        let pattern = #"Daily Octordle #(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            print("🔍 SHARE EXTENSION: Octordle pattern not found")
            return nil
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            print("🔍 SHARE EXTENSION: Could not extract puzzle number")
            return nil
        }
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract score from "Score: XX" line
        var totalScore = 0
        let scorePattern = #"Score:\s*(\d+)"#
        print("🔍 SHARE EXTENSION: Looking for score pattern: \(scorePattern)")
        if let scoreRegex = try? NSRegularExpression(pattern: scorePattern, options: .caseInsensitive),
           let scoreMatch = scoreRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
           scoreMatch.range(at: 1).location != NSNotFound,
           let scoreRange = Range(scoreMatch.range(at: 1), in: text) {
            totalScore = Int(String(text[scoreRange])) ?? 0
            print("🔍 SHARE EXTENSION: Found score: \(totalScore)")
        } else {
            // If no score line found, calculate from emoji grid
            print("🔍 SHARE EXTENSION: No score line found, calculating from emoji grid")
            totalScore = calculateScoreFromEmojiGrid(text)
            print("🔍 SHARE EXTENSION: Calculated score from emoji grid: \(totalScore)")
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
        
        print("🔍 SHARE EXTENSION: Extracted - Puzzle: \(puzzleNumber), Total Score: \(totalScore), Main Score: \(mainScore), Completed: \(isCompleted)")
        
        return [
            "id": UUID().uuidString,
            "gameId": "550e8400-e29b-41d4-a716-446655440200", // Octordle game ID
            "gameName": "octordle",
            "date": ISO8601DateFormatter().string(from: Date()),
            "score": mainScore, // Use the actual score from "Score: XX" line
            "maxAttempts": mainScore, // For Octordle, maxAttempts = score (attempts don't matter)
            "completed": isCompleted, // Only completed if NO red squares (🟥) appear
            "sharedText": text,
            "parsedData": [
                "puzzleNumber": puzzleNumber,
                "totalScore": "\(totalScore)",
                "completedWords": "\(completedWords)",
                "failedWords": "\(failedWords)",
                "completionRate": "\(completedWords)/8",
                "hasFailedWords": "\(hasFailedWords)",
                "gameType": "word_variant",
                "source": "shareExtension"
            ]
        ]
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
    
    private func saveResult(_ result: [String: Any]) {
        print("🔍 SHARE EXTENSION: Saving result...")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: result, options: [])
            let userDefaults = UserDefaults(suiteName: "group.com.mitsheth.StreakSync")
            
            // Save as latest result (main app expects this key)
            userDefaults?.set(data, forKey: "latestGameResult")
            
            // Also add to queued results array (main app expects this key)
            var queuedResults: [[String: Any]] = []
            if let existingData = userDefaults?.data(forKey: "gameResults"),
               let existingResults = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]] {
                queuedResults = existingResults
            }
            
            queuedResults.append(result)
            let queuedData = try JSONSerialization.data(withJSONObject: queuedResults, options: [])
            userDefaults?.set(queuedData, forKey: "gameResults")
            
            userDefaults?.set(Date(), forKey: "lastShareExtensionSave")
            userDefaults?.synchronize()
            
            print("🔍 SHARE EXTENSION: Result saved successfully to latestGameResult and gameResults (queue size: \(queuedResults.count))")
        } catch {
            print("🔍 SHARE EXTENSION: Failed to save result: \(error)")
        }
    }
    
    private func showResult(_ message: String) {
        let alert = UIAlertController(title: "Share Extension", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        present(alert, animated: true)
    }
}