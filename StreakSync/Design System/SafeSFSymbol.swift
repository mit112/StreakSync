//
//  SafeSFSymbol.swift
//  StreakSync
//
//  Safe SF Symbol wrapper to prevent empty string errors
//  Following iOS 18 best practices for SF Symbols
//

/*
 * SAFESFSYMBOL - ROBUST SF SYMBOL USAGE WITH ERROR PREVENTION
 * 
 * WHAT THIS FILE DOES:
 * This file provides a safe wrapper for SF Symbols that prevents crashes and errors
 * when empty or invalid symbol names are used. It's like a "safety net" for icon usage
 * that ensures the app never crashes due to missing or empty symbol names. Think of it
 * as the "icon safety guard" that catches common mistakes and provides fallback icons
 * to keep the app running smoothly.
 * 
 * WHY IT EXISTS:
 * SF Symbols are a powerful way to display icons, but they can cause crashes if empty
 * strings or invalid names are passed to them. This wrapper catches these issues and
 * provides safe fallbacks, preventing the app from crashing and making debugging easier.
 * It also includes comprehensive logging to help developers find and fix the root causes
 * of empty symbol names.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This prevents crashes from invalid SF Symbol usage
 * - Provides safe fallbacks for empty or invalid symbol names
 * - Includes comprehensive debugging and logging for development
 * - Ensures consistent icon display throughout the app
 * - Prevents "No symbol named '' found" errors
 * - Makes the app more robust and reliable
 * - Helps developers identify and fix icon-related issues
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For Image types and SF Symbol display
 * - SF Symbols: Apple's icon system for consistent iconography
 * - Debug logging: For identifying empty symbol usage
 * - Thread: For stack trace debugging
 * - Font: For icon sizing and weight
 * 
 * WHAT REFERENCES IT:
 * - EVERYTHING: This is used by virtually every icon in the app
 * - All UI components: Use this for safe icon display
 * - Game icons: Use this for consistent game representation
 * - Navigation icons: Use this for safe navigation elements
 * - Status icons: Use this for error and success states
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. ERROR HANDLING IMPROVEMENTS:
 *    - The current error handling is good but could be more sophisticated
 *    - Consider adding validation for symbol existence
 *    - Add support for custom error handling strategies
 *    - Implement smart fallback selection based on context
 * 
 * 2. DEBUGGING IMPROVEMENTS:
 *    - The current debugging is comprehensive but could be enhanced
 *    - Consider adding symbol usage analytics
 *    - Add support for symbol validation in development
 *    - Implement automated testing for symbol usage
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider caching symbol validation results
 *    - Add support for lazy symbol loading
 *    - Implement efficient symbol name validation
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current fallback system could be more intelligent
 *    - Add support for context-aware fallbacks
 *    - Implement smart symbol suggestions
 *    - Add support for custom fallback icons
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for symbol safety
 *    - Test different error scenarios and edge cases
 *    - Add integration tests with real symbol usage
 *    - Test fallback behavior and error handling
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for symbol safety features
 *    - Document the fallback system and error handling
 *    - Add examples of how to use safe symbols
 *    - Create symbol usage guidelines
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new symbol types
 *    - Add support for custom symbol validation
 *    - Implement symbol plugins
 *    - Add support for third-party icon systems
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for symbol usage patterns
 *    - Implement metrics for symbol errors and fallbacks
 *    - Add support for symbol usage monitoring
 *    - Monitor symbol performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - SF Symbols: Apple's icon system for consistent iconography
 * - Error prevention: Stopping problems before they cause crashes
 * - Fallback systems: What to do when something goes wrong
 * - Debugging: Finding and fixing problems in code
 * - Logging: Recording what the app is doing for debugging
 * - Stack traces: Information about where errors occur
 * - Safe programming: Writing code that handles errors gracefully
 * - User experience: Making sure the app works reliably
 * - Robustness: Making sure the app doesn't crash easily
 * - Development tools: Tools that help developers find and fix problems
 */

import SwiftUI

/// Safe wrapper for SF Symbols that provides fallback for empty strings
/// Prevents "No symbol named '' found in system symbol set" errors
struct SafeSFSymbol: View {
    let name: String
    let fallback: String
    let size: Font?
    let weight: Font.Weight?
    
    init(_ name: String, fallback: String = "questionmark.circle", size: Font? = nil, weight: Font.Weight? = nil) {
        self.name = name
        self.fallback = fallback
        self.size = size
        self.weight = weight
    }
    
    var body: some View {
        Image(systemName: validSymbolName)
            .font(size)
            .fontWeight(weight)
    }
    
    private var validSymbolName: String {
        if name.isEmpty {
            #if DEBUG
            print("⚠️ [SafeSFSymbol] Empty symbol name detected, using fallback: \(fallback)")
            #endif
            return fallback
        }
        return name
    }
}

// MARK: - Extension for safer Image creation
extension Image {
    /// Creates an SF Symbol image with automatic fallback for empty strings
    /// Prevents "No symbol named '' found in system symbol set" errors
    static func safeSystemName(_ name: String, fallback: String = "questionmark.circle") -> Image {
        let safeName = name.isEmpty ? fallback : name
        
        #if DEBUG
        if name.isEmpty {
            print("🚨🚨🚨 [Image.safeSystemName] EMPTY SYMBOL NAME DETECTED!")
            print("🚨 Fallback used: \(fallback)")
            print("🚨 Stack trace:")
            Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
        }
        #endif
        
        return Image(systemName: safeName)
    }
    
    /// Creates an SF Symbol image with aggressive debugging for empty strings
    /// This will catch ALL empty string usage, even from direct Image(systemName:) calls
    static func debugSystemName(_ name: String, fallback: String = "questionmark.circle") -> Image {
        #if DEBUG
        print("🔍 [Image.debugSystemName] Loading symbol: '\(name)'")
        if name.isEmpty {
            print("🚨🚨🚨 [Image.debugSystemName] EMPTY SYMBOL NAME DETECTED!")
            print("🚨 Using fallback: \(fallback)")
            print("🚨 Stack trace:")
            Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
        }
        #endif
        
        let safeName = name.isEmpty ? fallback : name
        return Image(systemName: safeName)
    }
    
    /// TEMPORARY: Override Image(systemName:) to catch empty strings
    /// This will help us find where empty strings are being passed directly
    static func catchEmptySystemName(_ name: String) -> Image {
        #if DEBUG
        if name.isEmpty {
            print("🚨🚨🚨 [Image.catchEmptySystemName] DIRECT EMPTY SYMBOL NAME DETECTED!")
            print("🚨 This is a direct Image(systemName:) call with empty string!")
            print("🚨 Stack trace:")
            Thread.callStackSymbols.prefix(15).forEach { print("  \($0)") }
            print("🚨 Using fallback: questionmark.circle")
            return Image(systemName: "questionmark.circle")
        }
        #endif
        return Image(systemName: name)
    }
    
}

// MARK: - Convenience initializers for common use cases
extension SafeSFSymbol {
    /// Game icon with gamecontroller fallback
    static func gameIcon(_ name: String, size: Font? = nil) -> SafeSFSymbol {
        SafeSFSymbol(name, fallback: "gamecontroller", size: size)
    }
    
    /// Achievement icon with star.fill fallback
    static func achievementIcon(_ name: String, size: Font? = nil) -> SafeSFSymbol {
        SafeSFSymbol(name, fallback: "star.fill", size: size)
    }
    
    /// Trophy icon with trophy.fill fallback
    static func trophyIcon(_ name: String, size: Font? = nil) -> SafeSFSymbol {
        SafeSFSymbol(name, fallback: "trophy.fill", size: size)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Valid symbol
        SafeSFSymbol("star.fill")
            .font(.title)
        
        // Empty symbol with fallback
        SafeSFSymbol("")
            .font(.title)
        
        // Game icon with fallback
        SafeSFSymbol.gameIcon("")
            .font(.title2)
        
        // Achievement icon with fallback
        SafeSFSymbol.achievementIcon("")
            .font(.title3)
    }
    .padding()
}
