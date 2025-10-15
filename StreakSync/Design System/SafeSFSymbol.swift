//
//  SafeSFSymbol.swift
//  StreakSync
//
//  Safe SF Symbol wrapper to prevent empty string errors
//  Following iOS 18 best practices for SF Symbols
//

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
