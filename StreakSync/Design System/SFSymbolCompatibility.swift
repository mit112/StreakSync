//
//  SFSymbolCompatibility.swift
//  StreakSync
//
//  SF Symbol compatibility system for iOS version differences
//

import SwiftUI
import UIKit

/// SF Symbol compatibility system that provides fallbacks for symbols not available in older iOS versions
struct SFSymbolCompatibility {
    
    /// Check if a symbol is available on the current iOS version
    static func isSymbolAvailable(_ symbolName: String) -> Bool {
        // Empty strings are never available
        if symbolName.isEmpty {
            return false
        }
        return UIImage(systemName: symbolName) != nil
    }
    
    /// Get a compatible symbol name with fallback for older iOS versions
    static func compatibleSymbol(_ symbolName: String, fallback: String) -> String {
        // Handle empty strings first
        if symbolName.isEmpty {
            #if DEBUG
            print("🚨 [SFSymbolCompatibility.compatibleSymbol] Empty symbol name detected, using fallback: '\(fallback)'")
            #endif
            return fallback
        }
        
        if isSymbolAvailable(symbolName) {
            return symbolName
        } else {
            #if DEBUG
            print("⚠️ [SFSymbolCompatibility] Symbol '\(symbolName)' not available, using fallback: '\(fallback)'")
            #endif
            return fallback
        }
    }
    
    /// Predefined symbol mappings for common symbols that might not be available in older iOS versions
    static let symbolMappings: [String: String] = [
        // Chart symbols
        "chart.line.uptrend.xyaxis": "chart.line.uptrend",
        "chart.bar.xaxis": "chart.bar",
        "chart.pie.fill": "chart.pie",
        
        // Decorative symbols
        "sparkle": "star.fill",
        "diamond.fill": "star.fill",
        "diamond": "star",
        
        // Newer UI symbols
        "line.3.horizontal.decrease.circle": "line.3.horizontal.decrease",
        "arrow.up.right.square": "arrow.up.right",
        
        // Game symbols
        "gamecontroller.fill": "gamecontroller",
        "trophy.fill": "trophy",
        "star.fill": "star"
    ]
    
    /// Get a symbol with automatic fallback based on predefined mappings
    static func getSymbol(_ symbolName: String) -> String {
        // Handle empty strings first
        if symbolName.isEmpty {
            #if DEBUG
            print("🚨 [SFSymbolCompatibility.getSymbol] Empty symbol name detected, using fallback: questionmark.circle")
            #endif
            return "questionmark.circle"
        }
        
        if let fallback = symbolMappings[symbolName] {
            return compatibleSymbol(symbolName, fallback: fallback)
        }
        return symbolName
    }
}

// MARK: - SwiftUI Extension
extension Image {
    /// Creates an SF Symbol image with automatic compatibility fallback
    static func compatibleSystemName(_ name: String, fallback: String? = nil) -> Image {
        let safeName = SFSymbolCompatibility.getSymbol(name)
        
        #if DEBUG
        if name.isEmpty {
            print("🚨🚨🚨 [Image.compatibleSystemName] EMPTY SYMBOL NAME DETECTED!")
            print("🚨 Original name: '\(name)'")
            print("🚨 Safe name: '\(safeName)'")
            print("🚨 Stack trace:")
            Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
        }
        if name != safeName {
            print("🔄 [Image.compatibleSystemName] '\(name)' → '\(safeName)' (compatibility fallback)")
        }
        #endif
        
        return Image(systemName: safeName)
    }
}

// MARK: - UIKit Extension
extension UIImage {
    /// Creates a UIImage with SF Symbol and automatic compatibility fallback
    static func compatibleSystemName(_ name: String, fallback: String? = nil) -> UIImage? {
        let safeName = SFSymbolCompatibility.getSymbol(name)
        
        #if DEBUG
        if name.isEmpty {
            print("🚨🚨🚨 [UIImage.compatibleSystemName] EMPTY SYMBOL NAME DETECTED!")
            print("🚨 Original name: '\(name)'")
            print("🚨 Safe name: '\(safeName)'")
            print("🚨 Stack trace:")
            Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
        }
        if name != safeName {
            print("🔄 [UIImage.compatibleSystemName] '\(name)' → '\(safeName)' (compatibility fallback)")
        }
        #endif
        
        return UIImage(systemName: safeName)
    }
}
