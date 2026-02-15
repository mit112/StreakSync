//
//  SafeSFSymbol.swift
//  StreakSync
//
//  Safe SF Symbol wrapper to prevent empty string errors
//

import SwiftUI
import OSLog

private let safeSFLogger = Logger(subsystem: "com.streaksync.app", category: "SafeSFSymbol")

// MARK: - Extension for safer Image creation
extension Image {
    /// Creates an SF Symbol image with automatic fallback for empty strings.
    /// Prevents "No symbol named '' found in system symbol set" errors.
    static func safeSystemName(_ name: String, fallback: String = "questionmark.circle") -> Image {
        let safeName = name.isEmpty ? fallback : name
        #if DEBUG
        if name.isEmpty {
            safeSFLogger.warning("Empty symbol name, using fallback: \(fallback)")
        }
        #endif
        return Image(systemName: safeName)
    }
}
