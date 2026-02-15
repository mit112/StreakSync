//
//  AccountView.swift
//  StreakSync
//
//  Account management — Apple Sign-In, Google Sign-In, profile display, sign out.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

@MainActor
struct AccountView: View {
    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var authManager: FirebaseAuthStateManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var profile: UserProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignOutConfirmation = false
    @State private var signInSuccess = false

    init(authManager: FirebaseAuthStateManager) {
        self._authManager = ObservedObject(wrappedValue: authManager)
    }

    var body: some View {
        Form {
            if authManager.isAnonymous {
                anonymousSection
            } else {
                profileSection
                signOutSection
            }
            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Account")
        .task { await loadProfile() }
    }
}

// MARK: - Anonymous Section

private extension AccountView {

    var anonymousSection: some View {
        Group {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("You're using StreakSync anonymously")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Sign in to set your display name so friends can recognize you on the leaderboard.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authManager.prepareAppleNonce()
                } onCompletion: { result in
                    Task { await handleAppleSignInResult(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)

                googleSignInButton
            } footer: {
                Text("Your existing streaks and scores will be preserved.")
            }

            if signInSuccess {
                Section {
                    Label("Signed in successfully!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    var googleSignInButton: some View {
        Button {
            Task { await handleGoogleSignIn() }
        } label: {
            HStack(spacing: 0) {
                Spacer()
                // Google "G" logo approximation
                Text("G")
                    .font(.title2.bold())
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue, .green, .yellow, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.trailing, 8)
                Text("Sign in with Google")
                    .font(.body.weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                Spacer()
            }
            .frame(height: 50)
            .background(colorScheme == .dark ? Color.white : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }
}

// MARK: - Signed-In Sections

private extension AccountView {

    var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 52, height: 52)
                    Text(initials)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(authManager.displayName ?? profile?.displayName ?? "Player")
                        .font(.headline)
                    if let email = authManager.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: authManager.authProvider == .google ? "g.circle" : "apple.logo")
                            .font(.caption2)
                        Text(authManager.authProvider == .google ? "Google Account" : "Apple Account")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Profile")
        }
    }

    var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await handleSignOut() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your personal streaks and scores stay on this device, but your leaderboard scores, friends, and friend code won't be visible until you sign back in.")
            }
        }
    }

    var initials: String {
        let name = authManager.displayName ?? profile?.displayName ?? "P"
        let parts = name.split(separator: " ")
        if parts.count >= 2, let f = parts.first?.first, let l = parts.last?.first {
            return "\(f)\(l)".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}

// MARK: - Actions

private extension AccountView {

    func loadProfile() async {
        do {
            profile = try await container.socialService.myProfile()
        } catch {
            // Not critical — profile might not exist yet for anonymous users
        }
    }

    func handleGoogleSignIn() async {
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
            signInSuccess = true
            await loadProfile()
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                signInSuccess = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) async {
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
                signInSuccess = true
                await loadProfile()
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    signInSuccess = false
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    func handleSignOut() async {
        await authManager.signOutAndReauthAnonymously()
        await loadProfile()
    }
}
