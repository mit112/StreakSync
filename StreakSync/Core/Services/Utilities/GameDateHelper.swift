//
//  GameDateHelper.swift
//  StreakSync
//
//  Helper for determining game status based on import time and game reset logic
//

import Foundation

struct GameDateHelper {
    
    /// Determines if a game result should be considered "today" based on when it was imported
    /// and the game's reset time (typically midnight)
    /// - Parameter importDate: The date when the game result was imported
    /// - Returns: True if the game should be considered "today", false otherwise
    static func isGameResultFromToday(_ importDate: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the start of today (midnight) - not used in current implementation
        let _ = calendar.startOfDay(for: now)
        
        // A game result is "today" if it was imported today
        // This is the correct logic because:
        // 1. If you import a result today, it means you played it today
        // 2. Games reset at midnight, so "today" means the current day
        // 3. The import time is the most accurate indicator of when you actually played
        return calendar.isDate(importDate, inSameDayAs: now)
    }
    
    /// Determines if a game result should be considered "yesterday" based on when it was imported
    /// - Parameter importDate: The date when the game result was imported
    /// - Returns: True if the game should be considered "yesterday", false otherwise
    static func isGameResultFromYesterday(_ importDate: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Get yesterday's date
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            return false
        }
        
        return calendar.isDate(importDate, inSameDayAs: yesterday)
    }
    
    /// Gets a user-friendly string describing when a game was played
    /// - Parameter importDate: The date when the game result was imported
    /// - Returns: A string like "Today", "Yesterday", or "X days ago"
    static func getGamePlayedDescription(_ importDate: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if isGameResultFromToday(importDate) {
            return "Today"
        } else if isGameResultFromYesterday(importDate) {
            return "Yesterday"
        } else {
            // Compare at day granularity (start-of-day) so we don't treat
            // "two calendar days ago" as "yesterday" once more than 24h passes.
            let startOfImport = calendar.startOfDay(for: importDate)
            let startOfNow = calendar.startOfDay(for: now)
            let days = calendar.dateComponents([.day], from: startOfImport, to: startOfNow).day ?? 0
            if days <= 0 {
                return "Today" // Fallback for edge cases
            } else if days == 1 {
                return "Yesterday"
            } else {
                return "\(days) days ago"
            }
        }
    }
    
    /// Checks if a game result is recent enough to be considered "active"
    /// - Parameter importDate: The date when the game result was imported
    /// - Returns: True if the game was played within the last 2 days
    static func isGameResultActive(_ importDate: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        // Active is defined at the calendar-day level: a game is "active"
        // if its last play date is today or yesterday.
        let startOfImport = calendar.startOfDay(for: importDate)
        let startOfNow = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: startOfImport, to: startOfNow).day ?? 0
        
        // Consider a game "active" if played within the last 1 day difference
        // (0 = today, 1 = yesterday). 2+ is no longer active.
        return days <= 1
    }
}
