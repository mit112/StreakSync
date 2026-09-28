//
//  SoundManager.swift
//  StreakSync
//
//  Manages sound effects for achievements and celebrations
//

import AVFoundation
import OSLog
import SwiftUI

// MARK: - Sound Manager
@MainActor
final class SoundManager {
    // MARK: - Singleton
    static let shared = SoundManager()
    
    // MARK: - Properties
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    private let logger = Logger(subsystem: "com.streaksync.app", category: "SoundManager")
    
    /// When the most recently scheduled sound plays. A sound requested inside
    /// `minimumSoundInterval` of it is pushed back rather than overlapping.
    private var lastSoundTime = Date.distantPast
    private let minimumSoundInterval: TimeInterval = 0.1 // 100ms minimum between sounds
    
    // MARK: - Sound Types
    enum SoundType: String, CaseIterable {
        case achievementUnlock = "achievement_unlock"
        case confetti = "confetti_burst"
        case woosh = "woosh"
        case pop = "pop"
        case success = "success_chime"
    }
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func play(_ type: SoundType) {
        guard soundEffectsEnabled else { return }
        
        let now = Date()
        let delay = lastSoundTime.addingTimeInterval(minimumSoundInterval).timeIntervalSince(now)
        guard delay > 0 else {
            lastSoundTime = now
            playSoundImmediately(type)
            return
        }
        
        // Reserve the next slot now so back-to-back requests stay in order and spaced.
        lastSoundTime = now.addingTimeInterval(delay)
        logger.info("Delaying sound: \(type.rawValue) (throttled)")
        Task {
            try? await Task.sleep(for: .seconds(delay))
            playSoundImmediately(type)
        }
    }
    
    private func playSoundImmediately(_ type: SoundType) {
        switch type {
        case .achievementUnlock, .success:
            AudioServicesPlaySystemSound(1025)
        case .pop:
            AudioServicesPlaySystemSound(1306)
        case .woosh:
            AudioServicesPlaySystemSound(1050)
        case .confetti:
            AudioServicesPlaySystemSound(1103)
        }
        
        logger.info("Playing sound: \(type.rawValue)")
    }
}
