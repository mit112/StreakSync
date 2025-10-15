//
//  SafeSymbol.swift
//  StreakSync
//
//  Safe SF Symbol wrapper that catches empty strings and provides fallbacks
//

import SwiftUI

/// Safe SF Symbol wrapper that prevents empty string errors
struct SafeSymbol: View {
    let name: String?
    let fallback: String
    let font: Font?
    let foregroundColor: Color?
    
    init(_ name: String?, fallback: String = "questionmark.circle", font: Font? = nil, foregroundColor: Color? = nil) {
        self.name = name
        self.fallback = fallback
        self.font = font
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        let symbolName = validSymbolName
        
        #if DEBUG
        if let name = name, name.isEmpty {
            print("🚨🚨🚨 [SafeSymbol] EMPTY SYMBOL NAME DETECTED!")
            print("🚨 Original name: '\(name)'")
            print("🚨 Using fallback: '\(fallback)'")
            print("🚨 Stack trace:")
            Thread.callStackSymbols.prefix(10).forEach { print("  \($0)") }
        }
        #endif
        
        return Image(systemName: symbolName)
            .font(font)
            .foregroundColor(foregroundColor)
    }
    
    private var validSymbolName: String {
        guard let name = name, !name.isEmpty else {
            return fallback
        }
        return name
    }
}

// MARK: - Convenience initializers
extension SafeSymbol {
    /// Game icon with gamecontroller fallback
    static func gameIcon(_ name: String?, font: Font? = nil) -> SafeSymbol {
        SafeSymbol(name, fallback: "gamecontroller", font: font)
    }
    
    /// Achievement icon with star.fill fallback
    static func achievementIcon(_ name: String?, font: Font? = nil) -> SafeSymbol {
        SafeSymbol(name, fallback: "star.fill", font: font)
    }
    
    /// Trophy icon with trophy.fill fallback
    static func trophyIcon(_ name: String?, font: Font? = nil) -> SafeSymbol {
        SafeSymbol(name, fallback: "trophy.fill", font: font)
    }
    
    /// Chart icon with chart.bar fallback
    static func chartIcon(_ name: String?, font: Font? = nil) -> SafeSymbol {
        SafeSymbol(name, fallback: "chart.bar", font: font)
    }
}

// MARK: - View Modifier for easy replacement
struct SafeSymbolModifier: ViewModifier {
    let name: String?
    let fallback: String
    
    func body(content: Content) -> some View {
        SafeSymbol(name, fallback: fallback)
    }
}

extension View {
    func safeSymbol(_ name: String?, fallback: String = "questionmark.circle") -> some View {
        SafeSymbol(name, fallback: fallback)
    }
}
