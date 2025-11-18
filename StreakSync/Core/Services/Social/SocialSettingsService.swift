//
//  SocialSettingsService.swift
//  StreakSync
//

import Foundation

enum SocialSharingScope: String, Codable, CaseIterable, Identifiable {
    case allFriends
    case circlesOnly
    case privateScope
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .allFriends: return "All friends"
        case .circlesOnly: return "Circles only"
        case .privateScope: return "Private"
        }
    }
}

struct SocialPrivacySettings: Codable {
    var perGameScopes: [UUID: SocialSharingScope]
    var shareIncompleteGames: Bool
    var hideZeroPointScores: Bool
    
    static let `default` = SocialPrivacySettings(
        perGameScopes: [:],
        shareIncompleteGames: true,
        hideZeroPointScores: false
    )
}

@MainActor
final class SocialSettingsService: ObservableObject {
    static let shared = SocialSettingsService()
    
    @Published private(set) var settings: SocialPrivacySettings
    private let defaults = UserDefaults.standard
    private let key = "social_privacy_settings"
    
    private init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SocialPrivacySettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }
    
    func scope(for gameId: UUID) -> SocialSharingScope {
        settings.perGameScopes[gameId] ?? .allFriends
    }
    
    func updateScope(_ scope: SocialSharingScope, for gameId: UUID) {
        settings.perGameScopes[gameId] = scope
        persist()
    }
    
    func updateShareIncompleteGames(_ value: Bool) {
        settings.shareIncompleteGames = value
        persist()
    }
    
    func updateHideZeroPointScores(_ value: Bool) {
        settings.hideZeroPointScores = value
        persist()
    }
    
    func shouldShare(score: DailyGameScore, game: Game?) -> Bool {
        if !settings.shareIncompleteGames && !score.completed {
            return false
        }
        if settings.hideZeroPointScores {
            let points = LeaderboardScoring.points(for: score, game: game)
            if points <= 0 { return false }
        }
        switch scope(for: score.gameId) {
        case .allFriends, .circlesOnly:
            return true
        case .privateScope:
            return false
        }
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}

