//
//  AchievementSyncStatusRow.swift
//  StreakSync
//
//  Data & Privacy row that says whether the achievement backup is actually working
//

import SwiftUI

/// A status row, not an alert. An achievement backup failure costs the user nothing
/// immediately — achievements live in local storage and are recomputed from game
/// results by `reconcileAfterResultSetChanged` — so it does not earn the app-wide
/// `SyncStatusBanner` treatment that a game-result sync failure gets. It earns an
/// honest line in the place the user goes to ask "is my data backed up?".
struct AchievementSyncStatusRow: View {
    let presentation: AchievementSyncStatusPresentation

    @ScaledMetric(relativeTo: .subheadline) private var symbolWidth: CGFloat = IconSize.sm

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: presentation.symbolName)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(presentation.title)
                    .font(.subheadline)
                    // Title stays .primary: the orange-on-orange tint that used to carry
                    // this kind of message measured ~2.2:1 and failed AA (SyncStatusBanner).
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let relativeDescription = relativeDescription {
                    Text(relativeDescription)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let detail = presentation.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel(relativeDescription: relativeDescription))
    }

    /// Formatted here rather than in the presentation so that type stays deterministic
    /// under test while the user still sees their own locale.
    private var relativeDescription: String? {
        presentation.relativeDate?.formatted(.relative(presentation: .named))
    }

    /// Tint only. The glyph and the title carry the state by themselves, so nothing is
    /// lost if the colours are indistinguishable (WCAG 2.2 AA, 1.4.1 Use of Colour).
    private var tint: Color {
        switch presentation.severity {
        case .neutral, .inProgress: return .secondary
        case .ok: return .green
        case .warning: return .orange
        }
    }
}
