//
//  SoundManager.swift
//  StreakSync
//
//  Manages sound effects for achievements and celebrations
//

import AVFoundation
import SwiftUI
import OSLog

// MARK: - Sound Manager
@MainActor
final class SoundManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SoundManager()
    
    // MARK: - Properties
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    private let logger = Logger(subsystem: "com.streaksync.app", category: "SoundManager")
    
    // MARK: - Sound Types
    enum SoundType: String, CaseIterable {
        case achievementUnlock = "achievement_unlock"
        case tierProgression = "tier_progression"
        case confetti = "confetti_burst"
        case woosh = "woosh"
        case pop = "pop"
        case success = "success_chime"
        
        var volume: Float {
            switch self {
            case .achievementUnlock: return 0.8
            case .tierProgression: return 0.7
            case .confetti: return 0.6
            case .woosh: return 0.5
            case .pop: return 0.4
            case .success: return 0.9
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        preloadSounds()
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
    
    private func preloadSounds() {
        for soundType in SoundType.allCases {
            loadSound(soundType)
        }
    }
    
    private func loadSound(_ type: SoundType) {
        // For now, we'll use system sounds. In production, you'd load custom sound files
        // Example: Bundle.main.url(forResource: type.rawValue, withExtension: "wav")
        
        // Create a simple system sound as placeholder
        switch type {
        case .achievementUnlock, .success:
            // Use system sound for now
            break
        default:
            break
        }
    }
    
    // MARK: - Public Methods
    
    func play(_ type: SoundType) {
        guard soundEffectsEnabled else { return }
        
        // Play system sound for now
        switch type {
        case .achievementUnlock, .success:
            AudioServicesPlaySystemSound(1025) // System sound
        case .pop:
            AudioServicesPlaySystemSound(1306)
        case .woosh:
            AudioServicesPlaySystemSound(1050)
        default:
            AudioServicesPlaySystemSound(1103)
        }
        
        logger.info("Playing sound: \(type.rawValue)")
    }
    
    func playSequence(_ types: [SoundType], delays: [TimeInterval]) {
        guard soundEffectsEnabled, types.count == delays.count else { return }
        
        for (index, type) in types.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delays[index]) { [weak self] in
                self?.play(type)
            }
        }
    }
}
