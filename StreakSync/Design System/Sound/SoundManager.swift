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
    
    // MARK: - Sound Queue Management
    private var soundQueue: [(SoundType, Date)] = []
    private var isPlayingSound = false
    private var lastSoundTime: Date = Date.distantPast
    private let minimumSoundInterval: TimeInterval = 0.1 // 100ms minimum between sounds
    
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
        
        let now = Date()
        
        // Check if we should throttle this sound
        if now.timeIntervalSince(lastSoundTime) < minimumSoundInterval {
            // Queue the sound instead of playing immediately
            soundQueue.append((type, now))
            logger.info("🎵 Queued sound: \(type.rawValue) (throttled)")
            return
        }
        
        // Play the sound immediately
        playSoundImmediately(type)
        lastSoundTime = now
        
        // Process queued sounds after a delay
        processQueuedSounds()
    }
    
    private func playSoundImmediately(_ type: SoundType) {
        // Play system sound for now
        switch type {
        case .achievementUnlock, .success:
            AudioServicesPlaySystemSound(1025) // System sound
        case .pop:
            AudioServicesPlaySystemSound(1306)
        case .woosh:
            AudioServicesPlaySystemSound(1050)
        case .confetti:
            AudioServicesPlaySystemSound(1103)
        default:
            AudioServicesPlaySystemSound(1103)
        }
        
        logger.info("🔊 Playing sound: \(type.rawValue)")
    }
    
    private func processQueuedSounds() {
        guard !soundQueue.isEmpty else { return }
        
        // Process the next queued sound after minimum interval
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumSoundInterval) { [weak self] in
            guard let self = self, !self.soundQueue.isEmpty else { return }
            
            let (nextSound, _) = self.soundQueue.removeFirst()
            self.playSoundImmediately(nextSound)
            self.lastSoundTime = Date()
            
            // Continue processing if there are more sounds
            if !self.soundQueue.isEmpty {
                self.processQueuedSounds()
            }
        }
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
