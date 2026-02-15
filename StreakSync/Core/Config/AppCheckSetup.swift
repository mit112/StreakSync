//
//  AppCheckSetup.swift
//  StreakSync
//
//  Configures Firebase App Check to prevent unauthorized API access.
//  Uses App Attest in production, debug provider in development.
//

import Foundation
import FirebaseCore
import FirebaseAppCheck

/// Factory that provides the appropriate App Check provider based on build configuration.
/// - Release: AppAttestProvider (hardware-backed attestation, blocks non-genuine clients)
/// - Debug: AppCheckDebugProvider (prints a debug token to console for Firebase Console registration)
class StreakSyncAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
