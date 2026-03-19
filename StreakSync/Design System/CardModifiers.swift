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
                let surfaceColor: Color = {
                    if colorScheme == .dark {
                        // Match prior dark mode look: near-black grouped surface.
                        return Color(.secondarySystemGroupedBackground)
                    } else {
                        // Light mode: crisp surface on top of grouped background.
                        return Color(.systemBackground)
                    }
                }()

                let borderColor: Color = {
                    if colorScheme == .dark {
                        // Subtle edge like the original design.
                        return Color(.separator)
                    } else {
                        // Light mode: slightly more defined edge to avoid washed-out look.
                        return Color.black.opacity(0.08)
                    }
                }()

                let borderWidth: CGFloat = (colorScheme == .dark ? 0.5 : 1)

                let shadowColor: Color = .black.opacity(colorScheme == .dark ? 0.2 : 0.10)
                let shadowRadius: CGFloat = (colorScheme == .dark ? 8 : 10)
                let shadowYOffset: CGFloat = (colorScheme == .dark ? 4 : 4)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surfaceColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                borderColor,
                                lineWidth: borderWidth
                            )
                    }
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: shadowYOffset
                    )
            }
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackgroundModifier(cornerRadius: cornerRadius))
    }
}
