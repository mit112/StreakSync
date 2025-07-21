//
//  GameCardModel.swift
//  StreakSync
//
//  Created by MiT on 7/23/25.
//

// DesignSystem/GameCards/GameCardModel.swift
import SwiftUI

/// Visual configuration for game cards
struct GameCardStyle {
    let gradient: LinearGradient
    let accentColor: Color
    let iconSize: CGFloat = 56
    
    static func style(for game: Game, colorScheme: ColorScheme) -> GameCardStyle {
        GameCardStyle(
            gradient: GradientSystem.GameGradients.gradient(for: game.name, colorScheme: colorScheme),
            accentColor: game.backgroundColor.color
        )
    }
}

/// Game card dimensions following design specs
enum GameCardDimensions {
    static let width: CGFloat = 340
    static let height: CGFloat = 460
    static let aspectRatio: CGFloat = 0.74 // width/height
    static let cornerRadius: CGFloat = 24
    static let padding: CGFloat = 24
    static let iconSize: CGFloat = 56
}
