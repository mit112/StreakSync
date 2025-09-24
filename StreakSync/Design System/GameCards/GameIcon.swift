//
//  GameIcon.swift
//  StreakSync
//
//  Enhanced game icon with sophisticated earthy palette treatments
//

import SwiftUI

struct GameIcon: View {
    let icon: String
    let backgroundColor: Color
    let size: CGFloat
    let gameType: GameType?
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(icon: String, backgroundColor: Color, size: CGFloat, gameType: GameType? = nil) {
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.size = size
        self.gameType = gameType
    }
    
    // Convenience initializer for Game
    init(game: Game, size: CGFloat) {
        self.icon = game.iconSystemName
        self.backgroundColor = game.backgroundColor.color
        self.size = size
        self.gameType = nil
    }

    var body: some View {
        ZStack {
            // Simplified background for now
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(backgroundColor.opacity(0.2))
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .stroke(backgroundColor.opacity(0.4), lineWidth: 1)
                }

            // Icon with appropriate styling
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(backgroundColor)
        }
    }
    
    // MARK: - Game-Specific Backgrounds
    @ViewBuilder
    private func gameSpecificBackground(for gameType: GameType) -> some View {
        switch gameType {
        case .wordle:
            wordleBackground
        case .quordle:
            quordleBackground
        case .connections:
            connectionsBackground
        case .spellingBee:
            spellingBeeBackground
        case .letterBoxed:
            letterBoxedBackground
        default:
            // Fallback to generic
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(backgroundColor)
                .frame(width: size, height: size)
        }
    }
    
    // MARK: - Individual Game Backgrounds
    private var wordleBackground: some View {
        let colors = StreakSyncColors.wordleIconColors(for: colorScheme)
        return ZStack {
            // Ash gray background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(colors.background)
                .frame(width: size, height: size)
            
            // Grid pattern overlay
            GridPattern(
                rows: 3,
                columns: 3,
                color: colors.grid,
                lineWidth: 1
            )
            .frame(width: size * 0.6, height: size * 0.6)
            .opacity(0.3)
        }
        .shadow(color: colors.background.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var quordleBackground: some View {
        let colors = StreakSyncColors.quordleIconColors(for: colorScheme)
        return ZStack {
            // Night background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(colors.background)
                .frame(width: size, height: size)
            
            // 2x2 grid pattern
            GridPattern(
                rows: 2,
                columns: 2,
                color: colors.borders,
                lineWidth: 1
            )
            .frame(width: size * 0.6, height: size * 0.6)
            .opacity(0.4)
        }
        .shadow(color: colors.background.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var connectionsBackground: some View {
        let colors = StreakSyncColors.connectionsIconColors(for: colorScheme)
        return ZStack {
            // Khaki background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(colors.background)
                .frame(width: size, height: size)
            
            // Dots pattern
            DotsPattern(
                color: colors.dots,
                dotSize: 2,
                spacing: 4
            )
            .frame(width: size * 0.6, height: size * 0.6)
            .opacity(0.6)
        }
        .shadow(color: colors.background.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var spellingBeeBackground: some View {
        let colors = StreakSyncColors.spellingBeeIconColors(for: colorScheme)
        return ZStack {
            // Auburn background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(colors.background)
                .frame(width: size, height: size)
            
            // Hexagon outline
            HexagonShape()
                .stroke(colors.outline, lineWidth: 2)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .shadow(color: colors.background.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var letterBoxedBackground: some View {
        let colors = StreakSyncColors.letterBoxedIconColors(for: colorScheme)
        return ZStack {
            // Cream background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(colors.background)
                .frame(width: size, height: size)
            
            // Square outline
            RoundedRectangle(cornerRadius: 4)
                .stroke(colors.outline, lineWidth: 2)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .shadow(color: colors.outline.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Icon Color
    private var iconColor: Color {
        if let gameType = gameType {
            switch gameType {
            case .wordle:
                return StreakSyncColors.wordleIconColors(for: colorScheme).accent
            case .quordle:
                return StreakSyncColors.quordleIconColors(for: colorScheme).borders
            case .connections:
                return StreakSyncColors.connectionsIconColors(for: colorScheme).connections
            case .spellingBee:
                return StreakSyncColors.spellingBeeIconColors(for: colorScheme).outline
            case .letterBoxed:
                return StreakSyncColors.letterBoxedIconColors(for: colorScheme).outline
            default:
                return backgroundColor
            }
        }
        return backgroundColor
    }
}

// MARK: - Supporting Views
private struct GridPattern: View {
    let rows: Int
    let columns: Int
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(columns)
            let cellHeight = size.height / CGFloat(rows)
            
            // Draw vertical lines
            for i in 0...columns {
                let x = CGFloat(i) * cellWidth
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(color),
                    lineWidth: lineWidth
                )
            }
            
            // Draw horizontal lines
            for i in 0...rows {
                let y = CGFloat(i) * cellHeight
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(color),
                    lineWidth: lineWidth
                )
            }
        }
    }
}

private struct DotsPattern: View {
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / (dotSize + spacing))
            let rows = Int(size.height / (dotSize + spacing))
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * (dotSize + spacing) + dotSize/2
                    let y = CGFloat(row) * (dotSize + spacing) + dotSize/2
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - dotSize/2,
                            y: y - dotSize/2,
                            width: dotSize,
                            height: dotSize
                        )),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2
        
        var path = Path()
        
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Game Type Enum
enum GameType: String, CaseIterable {
    case wordle = "wordle"
    case quordle = "quordle"
    case connections = "connections"
    case spellingBee = "spelling_bee"
    case letterBoxed = "letter_boxed"
    case custom = "custom"
}
