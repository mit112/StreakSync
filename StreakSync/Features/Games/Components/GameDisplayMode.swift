//
// GameDisplayMode.swift
//
//  Game display modes for dashboard
//

import Foundation

enum GameDisplayMode: String, CaseIterable, Codable {
    case card = "card"
    case grid = "grid"
    
    var iconName: String {
        switch self {
        case .card:
            return "square.stack"
        case .grid:
            return "square.grid.2x2"
        }
    }
    
    var displayName: String {
        switch self {
        case .card:
            return "Cards"
        case .grid:
            return "Grid"
        }
    }
}
