//
//  GameResultSeal.swift
//  StreakSync
//
//  Branded result hero: product mark, one game accent, score, and completion status
//

import SwiftUI

struct GameResultSeal: View {
    let result: GameResult
    let game: Game?
    let revealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var configuration: GameResultSealConfiguration {
        GameResultSealConfiguration.make(result: result, game: game)
    }

    /// Game colour is an accent only — it never fills the score or the status word, so the
    /// seal reads as StreakSync's mark rather than as the game's branding (§4.7).
    private var accent: Color {
        game?.backgroundColor.color ?? StreakSyncBrand.primary
    }

    private var statusTint: Color {
        result.completed ? StreakSyncBrand.success : .red
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            seal
            statusLabel
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(configuration.gameName), score \(configuration.score), \(configuration.statusText)"
        )
    }

    private var seal: some View {
        ZStack {
            // Non-grouped token: the detail sheet's own background is `systemBackground`,
            // and the grouped variant is pure white in light mode, which would make the
            // seal's surface vanish into the page.
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                }

            // The product mark sits behind the score as a watermark. It has to stay very
            // faint: the score covers the mark's centre tiles, so at higher opacity the
            // remaining corner tiles read as stray artefacts rather than as the mark.
            StreakSyncBrandMark(size: 104, showsBackground: false, accessibilityLabel: nil)
                .opacity(0.06)

            VStack(spacing: Spacing.xs) {
                Image.safeSystemName(configuration.gameSystemImage, fallback: "gamecontroller")
                    .font(.title3)
                    .foregroundStyle(accent)

                // Two lines and an aggressive floor: `displayScore` is not always short —
                // Quordle weekly reads "Weekly 6-5-9-4" and Pips "Medium - 2:34", both of
                // which a single 40pt line would ellipsize.
                Text(configuration.score)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(width: 140, height: 140)
        .scaleEffect(revealed || reduceMotion ? 1 : 0.85)
        .opacity(revealed ? 1 : 0)
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(response: 0.5, dampingFraction: 0.7),
            value: revealed
        )
    }

    private var statusLabel: some View {
        // Icon plus word, so completion never depends on colour alone.
        Label(configuration.statusText, systemImage: configuration.statusSystemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(statusTint)
            .opacity(revealed ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(reduceMotion ? 0 : 0.15), value: revealed)
    }
}
