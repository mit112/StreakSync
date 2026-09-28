//
//  AppleSignInFailure.swift
//  StreakSync
//
//  Maps a Sign in with Apple failure to a message the user can act on
//

import AuthenticationServices
import Foundation

extension Error {
    /// The message to show for a failed `SignInWithAppleButton` result, or nil when the
    /// user cancelled and nothing should be shown.
    ///
    /// `ASAuthorizationError`'s own description is the raw "The operation couldn't be
    /// completed. (com.apple.AuthenticationServices.AuthorizationError error 1000.)". It
    /// is what every device with no Apple Account signed in gets, right after the
    /// system's own "Sign in to your Apple Account" alert (2026-09-27 walkthrough).
    var appleSignInFailureMessage: String? {
        guard let authError = self as? ASAuthorizationError else { return localizedDescription }
        switch authError.code {
        case .canceled:
            return nil
        case .unknown, .failed, .invalidResponse, .notHandled, .notInteractive:
            return "Sign in with Apple didn't complete. "
                + "Make sure an Apple Account is signed in under Settings, then try again."
        default:
            return localizedDescription
        }
    }
}
