//
//  CardModifiers.swift
//  StreakSync
//
//  Reusable card background with proper light mode depth
//

import SwiftUI

struct CardBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                colorScheme == .dark
                                    ? Color(.separator).opacity(0.3)
                                    : Color(.separator).opacity(0.6),
                                lineWidth: colorScheme == .dark ? 0.5 : 1
                            )
                    }
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.15 : 0.07),
                        radius: 6, x: 0, y: 2
                    )
                    .shadow(
                        color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                        radius: 14, x: 0, y: 6
                    )
            }
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackgroundModifier(cornerRadius: cornerRadius))
    }
}
