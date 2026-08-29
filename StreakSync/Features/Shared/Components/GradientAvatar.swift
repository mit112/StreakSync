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
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    private var scaledSize: CGFloat { size * scale }

    var body: some View {
        ZStack {
            LinearGradient(colors: palette(for: initials), startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: scaledSize, height: scaledSize)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            Text(initials)
                .font(.system(size: scaledSize * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(radius: 1)
        }
        .frame(width: scaledSize, height: scaledSize)
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
        return palettes[Self.paletteIndex(for: key, count: palettes.count)]
    }

    /// Deterministic palette index so an avatar's gradient stays the same across
    /// launches. `String.hashValue` is seeded per process, so it can't be used
    /// as a stable identity anchor (DESIGN_AUDIT bug B3). Uses a djb2 hash of the
    /// UTF-8 bytes instead.
    static func paletteIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let hash = key.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
        return Int(hash % UInt64(count))
    }
}
