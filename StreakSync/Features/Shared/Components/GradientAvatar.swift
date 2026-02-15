//
//  GradientAvatar.swift
//  StreakSync
//
//  Animated gradient circle with initials, used in leaderboard rows and friend lists.
//

import SwiftUI

struct GradientAvatar: View {
    let initials: String
    var size: CGFloat = 32
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            LinearGradient(colors: palette(for: initials), startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            Text(initials)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(radius: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
    
    private func palette(for key: String) -> [Color] {
        let palettesLight: [[Color]] = [
            [Color.green, Color.mint, Color.teal],
            [Color.blue, Color.cyan, Color.indigo],
            [Color.orange, Color.pink, Color.red],
            [Color.purple, Color.indigo, Color.blue],
            [Color.yellow, Color.orange, Color.pink]
        ]
        let palettesDark: [[Color]] = [
            [Color.green.opacity(0.8), Color.teal.opacity(0.8), Color.black],
            [Color.blue.opacity(0.8), Color.indigo.opacity(0.8), Color.black],
            [Color.orange.opacity(0.8), Color.red.opacity(0.8), Color.black],
            [Color.purple.opacity(0.8), Color.indigo.opacity(0.8), Color.black],
            [Color.yellow.opacity(0.8), Color.orange.opacity(0.8), Color.black]
        ]
        let palettes = colorScheme == .dark ? palettesDark : palettesLight
        let idx = abs(key.hashValue) % palettes.count
        return palettes[idx]
    }
}
