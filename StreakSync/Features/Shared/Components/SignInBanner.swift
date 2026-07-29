//
//  SignInBanner.swift
//  StreakSync
//
//  Sign-in content for the Friends tab's `.signInRequired` state.
//  Not a stacked banner: it is only shown when sign-in is the dominant state.
//

import AuthenticationServices
import GoogleSignIn
import SwiftUI

struct SignInBanner: View {
    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var authManager: FirebaseAuthStateManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var errorMessage: String?
    @State private var isLoading = false

    init(authManager: FirebaseAuthStateManager) {
        self._authManager = ObservedObject(wrappedValue: authManager)
    }

    // No dismiss control and no `isAnonymous` gate of its own: the Friends state resolver
    // decides when sign-in is the dominant explanation, and dismissing the only
    // explanation would reveal a contradictory empty state (DESIGN_AUDIT §4.5).
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3)
                    .foregroundStyle(StreakSyncBrand.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to show your name")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Friends see you as \"Player\" on the leaderboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }

            // Apple is the prominent action, Google the secondary one.
            VStack(spacing: 10) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authManager.prepareAppleNonce()
                } onCompletion: { result in
                    Task { await handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 44)

                Button {
                    Task { await handleGoogleSignIn() }
                } label: {
                    GoogleSignInButtonLabel(height: 44)
                }
                .buttonStyle(.plain)
            }
            .disabled(isLoading)

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            do {
                try await authManager.handleAppleSignIn(authorization: authorization)
                let displayName = authManager.displayName
                try await container.socialService.updateProfile(
                    displayName: displayName,
                    authProvider: authManager.authProvider.rawValue
                )
                // No local dismissal: `authManager.isAnonymous` flipping re-resolves the
                // Friends state, which replaces this content with the leaderboard.
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleGoogleSignIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.handleGoogleSignIn()
            guard authManager.authProvider == .google else { return }
            let displayName = authManager.displayName
            try await container.socialService.updateProfile(
                displayName: displayName,
                authProvider: authManager.authProvider.rawValue
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
