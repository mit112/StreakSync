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
            
        default:
            logger.warning("Unknown URL scheme host: \(host)")
            return false
        }
    }
    
    // MARK: - Private Handlers
    private func handleNewResultLink() -> Bool {
        logger.info("Received new result URL scheme trigger")
        
        NotificationCenter.default.post(
            name: Notification.Name("HandleNewGameResult"),
            object: nil
        )
        
        return true
    }
    
    private func handleGameDeepLink(_ parameters: [String: String]) -> Bool {
        guard let gameParameter = parameters["name"] else {
            logger.warning("Game deep link missing name parameter")
            return false
        }
        
        let gameInfo: [String: String] = [
            "name": gameParameter,
            "id": parameters["id"] ?? ""
        ]
        
        NotificationCenter.default.post(
            name: .openGameRequested,
            object: gameInfo
        )
        
        logger.info("Handled game deep link for: \(gameParameter)")
        return true
    }
    
    private func handleAchievementDeepLink(_ parameters: [String: String]) -> Bool {
        guard let achievementId = parameters["id"] else {
            logger.warning("Achievement deep link missing id parameter")
            return false
        }
        
        NotificationCenter.default.post(
            name: .openAchievementRequested,
            object: achievementId
        )
        
        logger.info("Handled achievement deep link for: \(achievementId)")
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
