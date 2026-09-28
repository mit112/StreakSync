//
//  SocialSettingsService.swift
//  StreakSync
//
//  User-facing social sharing scope and privacy settings
//

import Foundation

enum SocialSharingScope: String, Codable, CaseIterable, Identifiable {
    case allFriends
    case privateScope
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .allFriends: return "All friends"
        case .privateScope: return "Private"
        }
    }
    
    // Migrate legacy "circlesOnly" values to allFriends
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SocialSharingScope(rawValue: raw) ?? .allFriends
    }
}

struct SocialPrivacySettings: Codable, Equatable {
    var perGameScopes: [UUID: SocialSharingScope]
    var shareIncompleteGames: Bool
    var hideZeroPointScores: Bool

    /// Whether friends see this game's scores, as a Bool a Toggle can bind to.
    subscript(sharesGame gameId: UUID) -> Bool {
        get { perGameScopes[gameId] != .privateScope }
        set { perGameScopes[gameId] = newValue ? .allFriends : .privateScope }
    }
    
    static let `default` = SocialPrivacySettings(
        perGameScopes: [:],
        shareIncompleteGames: true,
        hideZeroPointScores: false
    )
}

@MainActor
final class SocialSettingsService: ObservableObject {
    static let shared = SocialSettingsService()
    
    /// Settable so the Score Sharing screen can bind to it; every change is persisted.
    @Published var settings: SocialPrivacySettings {
        didSet { persist() }
    }
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
    }
    
    func updateShareIncompleteGames(_ value: Bool) {
        settings.shareIncompleteGames = value
    }
    
    func updateHideZeroPointScores(_ value: Bool) {
        settings.hideZeroPointScores = value
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
        case .allFriends:
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
