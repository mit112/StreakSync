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
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                Color(.separator),
                                lineWidth: colorScheme == .dark ? 0.5 : 1
                            )
                    }
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08),
                        radius: colorScheme == .dark ? 8 : 6,
                        x: 0,
                        y: colorScheme == .dark ? 4 : 2
                    )
            }
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackgroundModifier(cornerRadius: cornerRadius))
    }
}
