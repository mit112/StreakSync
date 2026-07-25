//
//  ShareDiscoverySheet.swift
//  StreakSync
//
//  Full-screen teaching sheet for the share-extension flow
//

import SwiftUI

struct ShareDiscoverySheet: View {
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismissEnv

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    ShareSheetMockup()
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        Text("Save your streak in 3 taps")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        let bodyText = "Finish a game in Wordle (or any of 16 supported games). "
                            + "Tap **Share**, then pick **StreakSync**. "
                            + "We'll record the result automatically."
                        Text(.init(bodyText))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }

            Button(action: handleDismiss) {
                Text("Got it")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .buttonStyle(.plain)
            .accessibilityLabel("Got it. Dismiss the share-discovery tutorial.")
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func handleDismiss() {
        HapticManager.shared.trigger(.buttonTap)
        onDismiss()
        dismissEnv()
    }
}

#Preview {
    ShareDiscoverySheet(onDismiss: {})
}
