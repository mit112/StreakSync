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

                // Separation is carried by the hairline border alone. A resting drop
                // shadow was redundant with the border (Impeccable `gpt-thin-border-wide-shadow`)
                // and, per Apple, hierarchy on iOS should come from layout/grouping/materials
                // rather than persistent decorative elevation — elevation is reserved for
                // temporary/adaptive state (WWDC25 356 & 219; UI audit §5.1, §7.2).
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surfaceColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                borderColor,
                                lineWidth: borderWidth
                            )
                    }
            }
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(CardBackgroundModifier(cornerRadius: cornerRadius))
    }
}
