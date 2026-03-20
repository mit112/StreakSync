//
//  GameResultDisplay.swift
//  StreakSync
//
//  Game-specific display score, emoji, and accessibility logic.
//  Extracted from SharedModels.swift for maintainability.
//

import Foundation

extension GameResult {
    // MARK: - Display Score
    var displayScore: String {
        // Special handling for multi-puzzle games like Quordle
        if gameName.lowercased() == Game.Names.quordle {
            return quordleDisplayScore
        }

        // Special handling for Pips difficulty-based scoring
        if gameName.lowercased() == Game.Names.pips {
            return pipsDisplayScore
        }

        // Special handling for Connections
        if gameName.lowercased() == Game.Names.connections {
            return connectionsDisplayScore
        }

        // Special handling for LinkedIn Zip
        if gameName.lowercased() == Game.Names.linkedinZip {
            return zipDisplayScore
        }

        // Special handling for LinkedIn Tango
        if gameName.lowercased() == Game.Names.linkedinTango {
            return tangoDisplayScore
        }

        // Special handling for LinkedIn Queens
        if gameName.lowercased() == Game.Names.linkedinQueens {
            return queensDisplayScore
        }

        // Special handling for LinkedIn Crossclimb
        if gameName.lowercased() == Game.Names.linkedinCrossclimb {
            return crossclimbDisplayScore
        }

        // Special handling for LinkedIn Pinpoint
        if gameName.lowercased() == Game.Names.linkedinPinpoint {
            return pinpointDisplayScore
        }

        // Special handling for NYT Strands
        if gameName.lowercased() == Game.Names.strands {
            return strandsDisplayScore
        }

        // Special handling for Octordle
        if gameName.lowercased() == Game.Names.octordle {
            return octordleDisplayScore
        }
        
        // Standard score display
        guard let score = score else {
            let formatString = NSLocalizedString("game.failed_score", comment: "X/%d")
            return String(format: formatString, maxAttempts)
        }
        return "\(score)/\(maxAttempts)"
    }
    
    private var quordleDisplayScore: String {
        let isWeekly = parsedData["mode"]?.lowercased() == "weekly"
        // Try to get individual scores from parsedData
        if let score1 = parsedData["score1"],
           let score2 = parsedData["score2"],
           let score3 = parsedData["score3"],
           let score4 = parsedData["score4"] {
            // Format as "6-5-9-4" or "X-X-X-X"
            let s1 = score1 == "failed" ? "X" : score1
            let s2 = score2 == "failed" ? "X" : score2
            let s3 = score3 == "failed" ? "X" : score3
            let s4 = score4 == "failed" ? "X" : score4
            
            let baseScore = "\(s1)-\(s2)-\(s3)-\(s4)"
            return isWeekly ? "Weekly \(baseScore)" : baseScore
        }
        
        // Fallback to standard display if individual scores not available
        guard let score = score else {
            return "X/\(maxAttempts)"
        }
        let baseScore = "\(score)/\(maxAttempts)"
        return isWeekly ? "Weekly \(baseScore)" : baseScore
    }
    
    private var pipsDisplayScore: String {
        // Get difficulty and time from parsedData
        if let difficulty = parsedData["difficulty"],
           let time = parsedData["time"] {
            return "\(difficulty) - \(time)"
        }
        
        // Fallback to standard display if difficulty/time not available
        guard let score = score else {
            return "X/\(maxAttempts)"
        }
        return "\(score)/\(maxAttempts)"
    }
    
    private var connectionsDisplayScore: String {
        // Get solved categories from parsedData
        if let solvedCategories = parsedData["solvedCategories"],
           let solved = Int(solvedCategories) {
            return "\(solved)/4"
        }
        
        // Fallback to score if available
        if let score = score {
            return "\(score)/4"
        }
        
        return "0/4"
    }
    
    private var zipDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var tangoDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var queensDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var crossclimbDisplayScore: String {
        // Get time from parsedData (this is the main score)
        if let time = parsedData["time"], !time.isEmpty {
            return time
        }
        
        // Fallback to score converted back to time format
        if let score = score, score > 0 {
            let minutes = score / 60
            let seconds = score % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        return "Completed"
    }
    
    private var pinpointDisplayScore: String {
        // Get guess count from parsedData (this is the main score)
        if let guessCount = parsedData["guessCount"], !guessCount.isEmpty {
            return "\(guessCount) guesses"
        }
        
        // Fallback to score converted to guess format
        if let score = score, score > 0 {
            return "\(score) guesses"
        }
        
        return "Completed"
    }
    
    private var strandsDisplayScore: String {
        // Get hint count from parsedData (this is the main score)
        if let hintCount = parsedData["hintCount"], !hintCount.isEmpty {
            let count = Int(hintCount) ?? 0
            return count == 0 ? "Perfect" : "\(count) hints"
        }
        
        // Fallback to score converted to hint format
        if let score = score {
            return score == 0 ? "Perfect" : "\(score) hints"
        }
        
        return "Completed"
    }
    
    private var octordleDisplayScore: String {
        // For Octordle, just show the score (not score/attempts)
        // Lower scores are better (8 is perfect, higher scores indicate more attempts)
        guard let score = score else {
            return "Failed"
        }
        
        return "\(score)"
    }
    
    var scoreEmoji: String {
        // Special handling for Quordle
        if gameName.lowercased() == Game.Names.quordle {
            return quordleScoreEmoji
        }

        // Special handling for LinkedIn Pinpoint (completed vs not completed)
        if gameName.lowercased() == Game.Names.linkedinPinpoint {
            return pinpointScoreEmoji
        }

        // Special handling for Pips difficulty-based emojis
        if gameName.lowercased() == Game.Names.pips {
            return pipsScoreEmoji
        }

        // Special handling for Connections
        if gameName.lowercased() == Game.Names.connections {
            return connectionsScoreEmoji
        }
        
        // Standard emoji
        guard let score = score else { return "❌" }
        switch score {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "✅"
        }
    }
    
    private var pinpointScoreEmoji: String {
        // For Pinpoint, explicitly show failure if not completed (e.g., 5/5 without pin)
        guard completed else { return "❌" }
        // Use typical attempt medals for low guess counts, checkmark otherwise
        guard let score = score else { return "✅" }
        switch score {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "✅"
        }
    }
    
    private var quordleScoreEmoji: String {
        // Check if all puzzles completed
        if let completedStr = parsedData["completedPuzzles"],
           let completed = Int(completedStr) {
            switch completed {
            case 4: return "🏆"  // All 4 completed
            case 3: return "🥉"  // 3 completed
            case 2: return "🥈"  // 2 completed
            case 1: return "🥇"  // 1 completed
            default: return "❌" // None completed
            }
        }
        
        // Fallback
        return completed ? "✅" : "❌"
    }
    
    private var pipsScoreEmoji: String {
        // Get difficulty from parsedData and return appropriate emoji
        if let difficulty = parsedData["difficulty"] {
            switch difficulty.lowercased() {
            case "easy": return "🟢"
            case "medium": return "🟡"
            case "hard": return "🟠"
            default: return "✅"
            }
        }
        
        // Fallback based on score
        guard let score = score else { return "❌" }
        switch score {
        case 1: return "🟢"  // Easy
        case 2: return "🟡"  // Medium
        case 3: return "🟠"  // Hard
        default: return "✅"
        }
    }
    
    private var connectionsScoreEmoji: String {
        // Get solved categories from parsedData
        if let solvedCategories = parsedData["solvedCategories"],
           let solved = Int(solvedCategories) {
            switch solved {
            case 4: return "🏆"  // Perfect - all 4 categories solved
            case 3: return "🥇"  // Great - 3/4 categories solved
            case 2: return "🥈"  // Good - 2/4 categories solved
            case 1: return "🥉"  // Partial - 1/4 categories solved
            default: return "❌" // Failed - 0 categories solved
            }
        }
        
        // Fallback based on score
        guard let score = score else { return "❌" }
        switch score {
        case 4: return "🏆"  // Perfect
        case 3: return "🥇"  // Great
        case 2: return "🥈"  // Good
        case 1: return "🥉"  // Partial
        default: return "❌" // Failed
        }
    }
    
    var accessibilityDescription: String {
        let statusText = completed ?
            NSLocalizedString("game.completed", comment: "Completed") :
            NSLocalizedString("game.failed", comment: "Failed")
        return NSLocalizedString("game.accessibility_description",
                                comment: "\(gameName), \(displayScore), \(statusText)")
    }
}
