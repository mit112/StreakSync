//
//  GoogleSignInButtonLabel.swift
//  StreakSync
//
//  Shared, brand-consistent label for the "Sign in with Google" button.
//

import SwiftUI

/// One Google sign-in treatment for both AccountView and SignInBanner
/// (DESIGN_AUDIT §5.5). Adaptive surface + hairline border + continuous corner
/// matched to the Apple button, and the full "Sign in with Google" label (never
/// a bare "Google"). A real multicolor Google "G" belongs in the asset catalog;
/// until one is added we use a single Google-blue monogram rather than the old
/// fake four-color gradient that misrepresented the logo.
struct GoogleSignInButtonLabel: View {
    var height: CGFloat = 50

    var body: some View {
        HStack(spacing: 8) {
            Text("G")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96)) // Google blue #4285F4
            Text("Sign in with Google")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.control, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sign in with Google")
        .accessibilityAddTraits(.isButton)
    }
}
