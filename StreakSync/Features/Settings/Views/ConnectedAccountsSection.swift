//
//  ConnectedAccountsSection.swift
//  StreakSync
//
//  Connect a second sign-in method (Apple/Google) to the same account.
//

import AuthenticationServices
import SwiftUI

/// Lets a signed-in user connect the *other* provider to the same Firebase UID, so they
/// can later sign in with either Apple or Google and reach the same streaks and scores.
/// Renders as a `Form` section; reports progress/errors back to the host via bindings.
@MainActor
struct ConnectedAccountsSection: View {
    @ObservedObject var authManager: FirebaseAuthStateManager
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Section {
            appleRow
            googleRow
        } header: {
            Text("Sign-in Methods")
        } footer: {
            Text("""
                Connect both so you can sign in with either Apple or Google and reach \
                the same streaks, scores, and friends.
                """)
        }
    }

    private var appleRow: some View {
        connectionRow(title: "Apple", systemImage: "apple.logo", isConnected: authManager.isAppleLinked) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
                request.nonce = authManager.prepareAppleNonce()
            } onCompletion: { result in
                Task { await handleAppleLink(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(width: 128, height: 34)
        }
    }

    private var googleRow: some View {
        connectionRow(title: "Google", systemImage: "g.circle", isConnected: authManager.isGoogleLinked) {
            Button("Connect") { Task { await handleGoogleLink() } }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func connectionRow<Control: View>(
        title: String,
        systemImage: String,
        isConnected: Bool,
        @ViewBuilder connectControl: () -> Control
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .accessibilityLabel("\(title) connected")
            } else {
                connectControl()
            }
        }
    }
}

// MARK: - Link Actions

private extension ConnectedAccountsSection {
    func handleAppleLink(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                try await authManager.linkApple(authorization: authorization)
            } catch {
                errorMessage = linkErrorMessage(for: error, provider: "Apple")
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    func handleGoogleLink() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authManager.linkGoogle()
        } catch {
            errorMessage = linkErrorMessage(for: error, provider: "Google")
        }
    }

    /// Turns a link failure into user-facing guidance. The important case is
    /// `accountExistsWithDifferentCredential` — the provider is already tied to a
    /// *different* account, so it can't be connected here.
    func linkErrorMessage(for error: Error, provider: String) -> String {
        if let authError = error as? FirebaseAuthError,
           case .accountExistsWithDifferentCredential = authError {
            return """
                That \(provider) account is already linked to a different StreakSync \
                account, so it can't be connected here.
                """
        }
        return error.localizedDescription
    }
}
