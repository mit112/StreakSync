//
//  SignInBanner.swift
//  StreakSync
//
//  Dismissible banner prompting anonymous users to sign in.
//  Shown at the top of the Friends tab.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct SignInBanner: View {
    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var authManager: FirebaseAuthStateManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("signInBannerDismissed") private var dismissed = false

    @State private var errorMessage: String?
    @State private var isLoading = false

    init(authManager: FirebaseAuthStateManager) {
        self._authManager = ObservedObject(wrappedValue: authManager)
    }

    var body: some View {
        if !dismissed && authManager.isAnonymous {
            bannerContent
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var bannerContent: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sign in to show your name")
                        .font(.subheadline.weight(.semibold))
                    Text("Friends see you as \"Player\" on the leaderboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { dismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
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
                    HStack(spacing: 6) {
                        Text("G")
                            .font(.callout.bold())
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.blue, .green, .yellow, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Google")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                    }
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                withAnimation(.easeOut(duration: 0.25)) { dismissed = true }
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
            withAnimation(.easeOut(duration: 0.25)) { dismissed = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
