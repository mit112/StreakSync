//
//  AppGroupURLSchemeHandler.swift
//  StreakSync
//
//  Handles URL scheme deep linking for the app
//

import Foundation
import OSLog

@MainActor
final class AppGroupURLSchemeHandler {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.streaksync.app", category: "URLSchemeHandler")
    
    // MARK: - URL Handling
    func handleURLScheme(_ url: URL) -> Bool {
 logger.info("Handling URL: \(url.absoluteString)")
        
        guard url.scheme == "streaksync" else {
 logger.error("Invalid URL scheme: \(url.scheme ?? "nil")")
            return false
        }
        
        guard let host = url.host else {
 logger.warning("URL missing host component")
            return false
        }
        
        let parameters = url.queryParameters
        
        switch host {
        case "newresult":
            return handleNewResultLink()
            
        case "game":
            return handleGameDeepLink(parameters)
            
        case "achievement":
            return handleAchievementDeepLink(parameters)
            
        case "join":
            return handleJoinDeepLink(parameters)
            
        default:
 logger.warning("Unknown URL scheme host: \(host)")
            return false
        }
    }
    
    // MARK: - Private Handlers
    private func handleNewResultLink() -> Bool {
 logger.info("Received new result URL scheme trigger")
        
        NotificationCenter.default.post(
            name: .appHandleNewGameResult,
            object: nil
        )
        
        return true
    }
    
    private func handleGameDeepLink(_ parameters: [String: String]) -> Bool {
        // Prefer UUID id when available; fall back to name for best-effort routing
        if let idString = parameters["id"], let uuid = UUID(uuidString: idString) {
            NotificationCenter.default.post(
                name: .openGameRequested,
                object: [AppConstants.DeepLinkKeys.gameId: uuid]
            )
 logger.info("Handled game deep link for id: \(uuid)")
            return true
        }
        if let name = parameters[AppConstants.DeepLinkKeys.name], !name.isEmpty {
            NotificationCenter.default.post(
                name: .openGameRequested,
                object: [AppConstants.DeepLinkKeys.name: name]
            )
 logger.info("Handled game deep link for name: \(name)")
            return true
        }
 logger.warning("Game deep link missing identifiers")
        return false
    }
    
    private func handleAchievementDeepLink(_ parameters: [String: String]) -> Bool {
        guard let idString = parameters["id"], let uuid = UUID(uuidString: idString) else {
 logger.warning("Achievement deep link missing or invalid id parameter")
            return false
        }
        
        NotificationCenter.default.post(
            name: .openAchievementRequested,
            object: [AppConstants.DeepLinkKeys.achievementId: uuid]
        )
        
 logger.info("Handled achievement deep link for: \(uuid)")
        return true
    }
    
    private func handleJoinDeepLink(_ parameters: [String: String]) -> Bool {
        guard let code = parameters["code"], !code.isEmpty else {
 logger.warning("Join deep link missing code parameter")
            return false
        }
        
        NotificationCenter.default.post(
            name: .joinGroupRequested,
            object: ["code": code]
        )
        
 logger.info("Handled join deep link with code: \(code)")
        return true
    }
}

// MARK: - URL Extensions
extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return [:]
        }
        
        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value ?? ""
        }
    }
}
