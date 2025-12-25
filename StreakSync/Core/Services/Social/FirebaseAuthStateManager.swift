//
//  FirebaseAuthStateManager.swift
//  StreakSync
//
//  Manages Firebase Authentication state with automatic re-authentication
//  for anonymous users when auth state changes unexpectedly.
//

import Foundation
import FirebaseAuth
import OSLog
import Combine

/// Manages Firebase Authentication state and provides reactive auth state updates.
/// Automatically re-authenticates anonymous users when they become signed out.
@MainActor
final class FirebaseAuthStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current Firebase user, nil if not authenticated
    @Published private(set) var currentUser: User?
    
    /// Whether the user is currently authenticated
    @Published private(set) var isAuthenticated: Bool = false
    
    /// Whether authentication is currently in progress
    @Published private(set) var isAuthenticating: Bool = false
    
    /// The last authentication error, if any
    @Published private(set) var authError: FirebaseAuthError?
    
    // MARK: - Private Properties
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let auth: Auth
    private let logger = Logger(subsystem: "com.streaksync.app", category: "FirebaseAuthStateManager")
    
    // MARK: - Initialization
    
    init(auth: Auth = Auth.auth()) {
        self.auth = auth
        self.currentUser = auth.currentUser
        self.isAuthenticated = auth.currentUser != nil
        setupAuthListener()
    }
    
    // Note: No deinit needed - this service lives for the app's entire lifecycle.
    // The auth listener will be cleaned up automatically when the app terminates.
    
    // MARK: - Public Methods
    
    /// The current user's UID, or nil if not authenticated
    var uid: String? {
        currentUser?.uid
    }
    
    /// Ensures the user is authenticated, signing in anonymously if needed
    func ensureAuthenticated() async {
        guard currentUser == nil else {
            logger.debug("User already authenticated: \(self.currentUser?.uid ?? "unknown", privacy: .private)")
            return
        }
        
        await signInAnonymously()
    }
    
    /// Signs in anonymously
    func signInAnonymously() async {
        guard !isAuthenticating else {
            logger.debug("Authentication already in progress, skipping")
            return
        }
        
        isAuthenticating = true
        authError = nil
        
        do {
            let result = try await auth.signInAnonymously()
            logger.info("✅ Firebase anonymous auth successful: uid=\(result.user.uid, privacy: .private)")
            // State will be updated by the auth listener
        } catch {
            let authError = FirebaseAuthError.from(error)
            self.authError = authError
            logger.error("❌ Firebase anonymous auth failed: \(authError.localizedDescription)")
        }
        
        isAuthenticating = false
    }
    
    /// Signs out the current user
    func signOut() {
        do {
            try auth.signOut()
            logger.info("✅ User signed out successfully")
        } catch {
            logger.error("❌ Sign out failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAuthListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let previousUser = self.currentUser
                self.currentUser = user
                self.isAuthenticated = user != nil
                
                if let user = user {
                    self.logger.info("🔐 Auth state: signed in (uid=\(user.uid, privacy: .private), isAnonymous=\(user.isAnonymous))")
                } else {
                    self.logger.info("🔐 Auth state: signed out")
                    
                    // If we were previously authenticated and now we're not,
                    // automatically re-authenticate anonymously
                    if previousUser != nil {
                        self.logger.info("🔄 Previous user lost, re-authenticating anonymously...")
                        await self.signInAnonymously()
                    }
                }
            }
        }
        
        logger.debug("Auth state listener configured")
    }
}

// MARK: - Firebase Auth Error

/// Represents Firebase authentication errors with user-friendly messages
enum FirebaseAuthError: LocalizedError {
    case networkUnavailable
    case tooManyRequests
    case operationNotAllowed
    case userDisabled
    case unknown(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Unable to connect. Please check your internet connection."
        case .tooManyRequests:
            return "Too many requests. Please try again later."
        case .operationNotAllowed:
            return "Anonymous sign-in is not enabled. Please contact support."
        case .userDisabled:
            return "This account has been disabled."
        case .unknown(let error):
            return "Authentication failed: \(error.localizedDescription)"
        }
    }
    
    /// Creates a FirebaseAuthError from an NSError
    static func from(_ error: Error) -> FirebaseAuthError {
        let nsError = error as NSError
        
        // Check for AuthErrorCode
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
        default:
            return .unknown(underlying: error)
        }
    }
}

