//
//  GameDateHelper.swift
//  StreakSync
//
//  Helper for determining game status based on import time and game reset logic
//

/*
 * GAMEDATEHELPER - INTELLIGENT DATE LOGIC AND GAME STATUS DETERMINATION
 * 
 * WHAT THIS FILE DOES:
 * This file provides intelligent date logic for determining when games were played
 * and their current status. It's like a "date intelligence system" that handles
 * the complex logic of determining if a game result is from today, yesterday,
 * or how long ago it was played. Think of it as the "temporal logic engine"
 * that makes sense of game timing and provides user-friendly descriptions
 * of when games were played.
 * 
 * WHY IT EXISTS:
 * Game timing is crucial for streak tracking and user experience. This helper
 * provides consistent, intelligent logic for determining game status based on
 * when results were imported, handling edge cases, and providing clear
 * user-friendly descriptions. It ensures that the app correctly understands
 * when games were played and can display this information clearly to users.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the foundation for streak tracking and game status
 * - Determines when games were played for accurate streak calculation
 * - Provides user-friendly descriptions of game timing
 * - Handles edge cases and timezone considerations
 * - Ensures consistent date logic throughout the app
 * - Supports streak maintenance and game status display
 * - Makes the app feel intelligent and responsive to user activity
 * 
 * WHAT IT REFERENCES:
 * - Foundation: For date and calendar functionality
 * - Calendar: For date calculations and comparisons
 * - Date: For date representation and manipulation
 * - DateComponents: For precise date calculations
 * 
 * WHAT REFERENCES IT:
 * - AppState: Uses this for determining game status and streaks
 * - Game result processing: Uses this for timing calculations
 * - Streak tracking: Uses this for maintaining accurate streaks
 * - UI components: Use this for displaying game timing information
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. DATE LOGIC IMPROVEMENTS:
 *    - The current logic is good but could be more sophisticated
 *    - Consider adding timezone support for global users
 *    - Add support for different game reset times
 *    - Implement smart date logic based on game type
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current date descriptions could be more user-friendly
 *    - Add support for localized date descriptions
 *    - Implement smart date formatting based on context
 *    - Add support for relative time descriptions
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient date calculations
 *    - Add support for date caching and reuse
 *    - Implement smart date management
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for date logic
 *    - Test different date scenarios and edge cases
 *    - Add timezone testing
 *    - Test with different calendar systems
 * 
 * 5. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for date logic
 *    - Document the different date scenarios and edge cases
 *    - Add examples of how to use different date functions
 *    - Create date logic usage guidelines
 * 
 * 6. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new date logic
 *    - Add support for custom date configurations
 *    - Implement date logic plugins
 *    - Add support for third-party date integrations
 * 
 * 7. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for date calculations
 *    - Implement metrics for date logic effectiveness
 *    - Add support for date debugging
 *    - Monitor date logic performance and reliability
 * 
 * 8. EDGE CASE HANDLING:
 *    - The current edge case handling could be enhanced
 *    - Add support for more complex date scenarios
 *    - Implement smart edge case detection
 *    - Add support for date validation and correction
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Date logic: Complex calculations for determining when events occurred
 * - Calendar systems: Different ways of organizing and calculating time
 * - Timezone handling: Managing time across different geographic regions
 * - Edge cases: Unusual or unexpected scenarios that need special handling
 * - User experience: Making sure date information is clear and helpful
 * - Streak tracking: Maintaining accurate records of consecutive activities
 * - Date formatting: Presenting date information in a user-friendly way
 * - Code organization: Keeping related functionality together
 * - Testing: Ensuring date logic works correctly in all scenarios
 * - Performance: Making sure date calculations are efficient
 */

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
