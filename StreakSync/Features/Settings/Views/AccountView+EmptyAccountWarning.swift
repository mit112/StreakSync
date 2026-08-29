//
//  AccountView+EmptyAccountWarning.swift
//  StreakSync
//
//  Tells the user when they've landed on a brand-new, empty account
//

import SwiftUI

extension AccountView {
    /// Shown when a sign-in produced a new, empty account using a provider this device
    /// has never seen. The previous session's data is already archived locally by the
    /// time this renders, so the message is about recovery, not loss.
    ///
    /// Deliberately an inline section rather than a modal: nothing is at stake in the
    /// next few seconds, and interrupting someone right after a sign-in they thought
    /// worked is worse than telling them plainly where their streaks went.
    @ViewBuilder
    func emptyAccountSwitchSection(
        _ warning: EmptyAccountSwitchWarning,
        onDismiss: @escaping () -> Void
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(
                    "This \(warning.newProviderLabel) account is empty",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

                Text(recoveryMessage(for: warning))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Got it", action: onDismiss)
                .font(.subheadline.weight(.semibold))
                .minTapTarget()
            }
            .padding(.vertical, Spacing.xs)
            .accessibilityElement(children: .contain)
        }
    }

    private func recoveryMessage(for warning: EmptyAccountSwitchWarning) -> String {
        let results = warning.archivedResultCount == 1
            ? "1 result"
            : "\(warning.archivedResultCount) results"
        return """
            You signed in with \(warning.newProviderLabel), which has no StreakSync \
            history. Your \(results) are still saved on this device — sign out and sign \
            back in with \(warning.previousProviderLabel) to get them back.
            """
    }
}
