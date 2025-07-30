//
// GameDisplayMode.swift
//
//  Game display modes for dashboard
//

import Foundation

enum GameDisplayMode: String, CaseIterable, Codable {
    case card = "card"
    case list = "list"
    case compact = "compact"
    
    var iconName: String {
        switch self {
        case .card:
            return "square.stack"
        case .list:
            return "list.bullet"
        case .compact:
            return "square.grid.2x2"
        }
    }
    
    var displayName: String {
        switch self {
        case .card:
            return "Cards"
        case .list:
            return "List"
        case .compact:
            return "Grid"
        }
    }
}
