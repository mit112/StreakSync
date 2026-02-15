//
//  FirebaseAuthStateManager.swift
//  StreakSync
//
//  Manages Firebase Authentication state with Apple Sign-In
//  and anonymous fallback. Supports linking anonymous accounts
//  to Apple credentials to preserve existing data.
//

import Foundation
@preconcurrency import FirebaseAuth
import AuthenticationServices
@preconcurrency import GoogleSignIn
import FirebaseCore
import CryptoKit
import OSLog
import Combine

/// The authentication provider used for the current session.
enum AuthProvider: String, Codable {
    case anonymous
    case apple
    case google
}

/// Manages Firebase Authentication state and provides reactive auth state updates.
@MainActor
final class FirebaseAuthStateManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var authError: FirebaseAuthError?
    @Published private(set) var authProvider: AuthProvider = .anonymous

    // MARK: - Private Properties

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let auth: Auth
    private let logger = Logger(subsystem: "com.streaksync.app", category: "FirebaseAuthStateManager")

    /// Nonce used for the current Apple Sign-In flow (unhashed).
    private var currentNonce: String?

    // MARK: - Initialization

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
        self.currentUser = auth.currentUser
        self.isAuthenticated = auth.currentUser != nil
        self.authProvider = Self.detectProvider(for: auth.currentUser)
        setupAuthListener()
    }

    // MARK: - Public Computed Properties

    var uid: String? { currentUser?.uid }

    var isAnonymous: Bool { currentUser?.isAnonymous ?? true }

    var displayName: String? { currentUser?.displayName }

    var email: String? { currentUser?.email }

    // MARK: - Anonymous Auth

    func ensureAuthenticated() async {
        guard currentUser == nil else {
            logger.debug("User already authenticated: \(self.currentUser?.uid ?? "unknown", privacy: .private)")
            return
        }
        await signInAnonymously()
    }

    func signInAnonymously() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil
        do {
            let result = try await auth.signInAnonymously()
            authProvider = .anonymous
            logger.info("✅ Anonymous auth: uid=\(result.user.uid, privacy: .private)")
        } catch {
            authError = FirebaseAuthError.from(error)
            logger.error("❌ Anonymous auth failed: \(error.localizedDescription)")
        }
        isAuthenticating = false
    }

    // MARK: - Apple Sign-In

    /// Generates a nonce for the Apple Sign-In flow and returns its SHA256 hash.
    /// Call this in `SignInWithAppleButton`'s `onRequest` closure to set `request.nonce`.
    func prepareAppleNonce() -> String {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        return Self.sha256(nonce)
    }

    /// Handles the Apple Sign-In credential after the user completes the ASAuthorizationController flow.
    /// If the user is currently anonymous, this links the Apple credential to preserve the UID.
    func handleAppleSignIn(authorization: ASAuthorization) async throws {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw FirebaseAuthError.invalidCredential
        }
        guard let nonce = currentNonce else {
            throw FirebaseAuthError.missingNonce
        }
        guard let identityToken = appleCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw FirebaseAuthError.invalidCredential
        }

        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        let credential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        do {
            if let existingUser = auth.currentUser, existingUser.isAnonymous {
                // Link anonymous account → Apple to preserve UID + data
                let user = existingUser
                let result = try await user.link(with: credential)
                logger.info("✅ Linked anonymous account to Apple: uid=\(result.user.uid, privacy: .private)")
                // Update display name from Apple if provided
                await updateDisplayNameFromApple(appleCredential.fullName, user: result.user)
            } else {
                // Fresh sign-in (or re-auth)
                let result = try await auth.signIn(with: credential)
                logger.info("✅ Apple Sign-In: uid=\(result.user.uid, privacy: .private)")
                await updateDisplayNameFromApple(appleCredential.fullName, user: result.user)
            }
            authProvider = .apple
            currentNonce = nil
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            // The Apple credential is already linked to a different Firebase account.
            // Sign in with that account instead (user previously signed in on another device).
            logger.warning("⚠️ Apple credential already in use — signing in to existing account")
            if let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                let result = try await auth.signIn(with: updatedCredential)
                logger.info("✅ Signed in to existing Apple account: uid=\(result.user.uid, privacy: .private)")
                authProvider = .apple
            } else {
                // Fallback: try signing in directly
                let result = try await auth.signIn(with: credential)
                authProvider = .apple
                logger.info("✅ Fallback Apple sign-in: uid=\(result.user.uid, privacy: .private)")
            }
            currentNonce = nil
        } catch {
            authError = FirebaseAuthError.from(error)
            logger.error("❌ Apple Sign-In failed: \(error.localizedDescription)")
            currentNonce = nil
            throw authError!
        }
    }

    // MARK: - Google Sign-In

    /// Initiates Google Sign-In. Presents the Google sign-in sheet over the given window scene.
    /// If the user is currently anonymous, links the Google credential to preserve the UID.
    func handleGoogleSignIn() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw FirebaseAuthError.operationNotAllowed
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            throw FirebaseAuthError.unknown(underlying: NSError(domain: "FirebaseAuthStateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"]))
        }

        // Find the topmost presented VC
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        isAuthenticating = true
        authError = nil
        defer { isAuthenticating = false }

        do {
            let presenter = topVC
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw FirebaseAuthError.invalidCredential
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            if let existingUser = auth.currentUser, existingUser.isAnonymous {
                // Link anonymous account → Google to preserve UID + data
                let user = existingUser
                let linkResult = try await user.link(with: credential)
                logger.info("✅ Linked anonymous account to Google: uid=\(linkResult.user.uid, privacy: .private)")
                await updateDisplayNameFromGoogle(result.user, firebaseUser: linkResult.user)
            } else {
                // Fresh sign-in
                let authResult = try await auth.signIn(with: credential)
                logger.info("✅ Google Sign-In: uid=\(authResult.user.uid, privacy: .private)")
                await updateDisplayNameFromGoogle(result.user, firebaseUser: authResult.user)
            }
            authProvider = .google
        } catch let error as GIDSignInError where error.code == .canceled {
            // User cancelled — not an error
            logger.debug("Google Sign-In cancelled by user")
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            // Google credential already linked to another Firebase account
            logger.warning("⚠️ Google credential already in use — signing in to existing account")
            if let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                let authResult = try await auth.signIn(with: updatedCredential)
                authProvider = .google
                logger.info("✅ Signed in to existing Google account: uid=\(authResult.user.uid, privacy: .private)")
            } else {
                authError = FirebaseAuthError.accountExistsWithDifferentCredential
                throw FirebaseAuthError.accountExistsWithDifferentCredential
            }
        } catch {
            authError = FirebaseAuthError.from(error)
            logger.error("❌ Google Sign-In failed: \(error.localizedDescription)")
            throw authError!
        }
    }

    private func updateDisplayNameFromGoogle(_ googleUser: GIDGoogleUser, firebaseUser: User) async {
        let name = googleUser.profile?.name
        guard let name, !name.isEmpty, firebaseUser.displayName == nil || firebaseUser.displayName?.isEmpty == true else { return }
        let changeRequest = firebaseUser.createProfileChangeRequest()
        changeRequest.displayName = name
        if let photoURL = googleUser.profile?.imageURL(withDimension: 200) {
            changeRequest.photoURL = photoURL
        }
        let request = changeRequest
        do {
            try await request.commitChanges()
            logger.info("✅ Updated Firebase display name from Google: \(name)")
        } catch {
            logger.warning("⚠️ Failed to set display name from Google: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            authProvider = .anonymous
            logger.info("✅ Signed out")
        } catch {
            logger.error("❌ Sign out failed: \(error.localizedDescription)")
        }
    }

    /// Signs out and creates a fresh anonymous session.
    func signOutAndReauthAnonymously() async {
        signOut()
        await signInAnonymously()
    }

    // MARK: - Private: Auth Listener

    private func setupAuthListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let previousUser = self.currentUser
                self.currentUser = user
                self.isAuthenticated = user != nil
                self.authProvider = Self.detectProvider(for: user)

                if let user {
                    self.logger.info("🔐 Auth: signed in (uid=\(user.uid, privacy: .private), anon=\(user.isAnonymous), provider=\(self.authProvider.rawValue))")
                } else {
                    self.logger.info("🔐 Auth: signed out")
                    if previousUser != nil {
                        self.logger.info("🔄 Re-authenticating anonymously…")
                        await self.signInAnonymously()
                    }
                }
            }
        }
    }

    // MARK: - Private: Helpers

    private func updateDisplayNameFromApple(_ fullName: PersonNameComponents?, user: User) async {
        guard let fullName else { return }
        let name = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
        guard !name.isEmpty else { return }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        let request = changeRequest
        do {
            try await request.commitChanges()
            logger.info("✅ Updated Firebase display name: \(name)")
        } catch {
            logger.warning("⚠️ Failed to set display name: \(error.localizedDescription)")
        }
    }

    private static func detectProvider(for user: User?) -> AuthProvider {
        guard let user else { return .anonymous }
        if user.isAnonymous { return .anonymous }
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) { return .apple }
        if user.providerData.contains(where: { $0.providerID == "google.com" }) { return .google }
        return .anonymous
    }

    // MARK: - Nonce Utilities

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Firebase Auth Error

enum FirebaseAuthError: LocalizedError {
    case networkUnavailable
    case tooManyRequests
    case operationNotAllowed
    case userDisabled
    case invalidCredential
    case missingNonce
    case accountExistsWithDifferentCredential
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Unable to connect. Please check your internet connection."
        case .tooManyRequests:
            return "Too many requests. Please try again later."
        case .operationNotAllowed:
            return "This sign-in method is not enabled."
        case .userDisabled:
            return "This account has been disabled."
        case .invalidCredential:
            return "Invalid sign-in credentials. Please try again."
        case .missingNonce:
            return "Authentication session expired. Please try again."
        case .accountExistsWithDifferentCredential:
            return "An account already exists with a different sign-in method."
        case .unknown(let error):
            return "Authentication failed: \(error.localizedDescription)"
        }
    }

    static func from(_ error: Error) -> FirebaseAuthError {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return .unknown(underlying: error)
        }
        guard let errorCode = AuthErrorCode(_bridgedNSError: nsError) else {
            return .unknown(underlying: error)
        }
        switch errorCode.code {
        case .networkError:
            return .networkUnavailable
        case .tooManyRequests:
            return .tooManyRequests
        case .operationNotAllowed:
            return .operationNotAllowed
        case .userDisabled:
            return .userDisabled
        case .invalidCredential:
            return .invalidCredential
        case .accountExistsWithDifferentCredential:
            return .accountExistsWithDifferentCredential
        default:
            return .unknown(underlying: error)
        }
    }
}
