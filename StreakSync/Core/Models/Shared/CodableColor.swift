//
//  CodableColor.swift
//  StreakSync
//
//  Thread-safe codable color wrapper.
//  Extracted from SharedModels.swift for maintainability.
//

import Foundation
import UIKit
import SwiftUI
import OSLog

// MARK: - Thread-Safe Codable Color (Memory Optimized)
struct CodableColor: Codable, Hashable, Sendable {
    private let colorData: ColorData
    // Add to CodableColor:
    var color: Color {
        Color(uiColor: self.uiColor)
    }
    init(_ color: UIColor) {
        // Safe color mapping with comprehensive cases
        switch color {
        case UIColor.systemRed: self.colorData = .systemRed
        case UIColor.systemBlue: self.colorData = .systemBlue
        case UIColor.systemGreen: self.colorData = .systemGreen
        case UIColor.systemPurple: self.colorData = .systemPurple
        case UIColor.systemPink: self.colorData = .systemPink
        case UIColor.systemYellow: self.colorData = .systemYellow
        case UIColor.systemOrange: self.colorData = .systemOrange
        case UIColor.systemGray: self.colorData = .systemGray
        case UIColor.systemTeal: self.colorData = .systemTeal
        case UIColor.systemIndigo: self.colorData = .systemIndigo
        case UIColor.systemCyan: self.colorData = .systemCyan
        default:
            // Extract RGB components safely
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                self.colorData = .custom(red: Double(red), green: Double(green), blue: Double(blue))
            } else {
                // Fallback for colors that can't be converted
                self.colorData = .systemBlue
                let logger = Logger(subsystem: "com.streaksync.models", category: "CodableColor")
 logger.error("Failed to convert UIColor to CodableColor, using systemBlue fallback")
            }
        }
    }
    
    private init(colorData: ColorData) {
        self.colorData = colorData
    }
    
    var uiColor: UIColor {
        switch colorData {
        case .systemRed: return .systemRed
        case .systemBlue: return .systemBlue
        case .systemGreen: return .systemGreen
        case .systemPurple: return .systemPurple
        case .systemPink: return .systemPink
        case .systemYellow: return .systemYellow
        case .systemOrange: return .systemOrange
        case .systemGray: return .systemGray
        case .systemTeal: return .systemTeal
        case .systemIndigo: return .systemIndigo
        case .systemCyan: return .systemCyan
        case .custom(let red, let green, let blue):
            return UIColor(displayP3Red: red, green: green, blue: blue, alpha: 1.0)
        }
    }
    
    // MARK: - Color Data Enum (Thread-Safe)
    private enum ColorData: Codable, Hashable, Sendable {
        case systemRed
        case systemBlue
        case systemGreen
        case systemPurple
        case systemPink
        case systemYellow
        case systemOrange
        case systemGray
        case systemTeal
        case systemIndigo
        case systemCyan
        case custom(red: Double, green: Double, blue: Double)
    }
    
    // MARK: - Static Factory Methods
    static let red = CodableColor(colorData: .systemRed)
    static let blue = CodableColor(colorData: .systemBlue)
    static let green = CodableColor(colorData: .systemGreen)
    static let purple = CodableColor(colorData: .systemPurple)
    static let pink = CodableColor(colorData: .systemPink)
    static let yellow = CodableColor(colorData: .systemYellow)
    static let orange = CodableColor(colorData: .systemOrange)
    static let gray = CodableColor(colorData: .systemGray)
    static let teal = CodableColor(colorData: .systemTeal)
    static let indigo = CodableColor(colorData: .systemIndigo)
    static let cyan = CodableColor(colorData: .systemCyan)
}

