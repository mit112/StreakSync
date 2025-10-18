//
//  SoundManager.swift
//  StreakSync
//
//  Manages sound effects for achievements and celebrations
//

/*
 * SOUNDMANAGER - AUDIO FEEDBACK AND CELEBRATION SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This file provides a centralized system for managing sound effects throughout the app.
 * It's like a "sound effects coordinator" that plays appropriate audio feedback for
 * different user actions and achievements. Think of it as the "audio celebration system"
 * that makes the app feel more engaging and rewarding by providing satisfying sound
 * effects for achievements, progress, and important events.
 * 
 * WHY IT EXISTS:
 * Sound effects enhance the user experience by providing audio feedback that makes
 * interactions feel more satisfying and engaging. This manager ensures that all
 * sound effects are consistent, appropriate, and don't overwhelm the user. It
 * provides different types of sounds for different events, making the app feel
 * more polished and rewarding to use.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enhances user experience with audio feedback
 * - Provides consistent sound effects across all interactions
 * - Supports different types of sounds for different events
 * - Manages sound queuing and throttling to prevent audio spam
 * - Integrates with user preferences for sound control
 * - Makes achievements and progress feel more rewarding
 * - Provides accessibility benefits for users with visual impairments
 * 
 * WHAT IT REFERENCES:
 * - AVFoundation: Apple's audio framework for sound playback
 * - AVAudioSession: For managing audio session and playback
 * - AVAudioPlayer: For playing sound effects
 * - OSLog: For logging and debugging audio issues
 * - AppStorage: For persisting user sound preferences
 * - SoundType: Enum defining different types of sound effects
 * 
 * WHAT REFERENCES IT:
 * - Achievement system: Uses this to celebrate achievement unlocks
 * - Progress tracking: Uses this to celebrate milestone progress
 * - Game interactions: Uses this to provide audio feedback
 * - Celebration views: Use this to enhance celebrations with sound
 * - Settings: Can configure sound preferences
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. SOUND SYSTEM IMPROVEMENTS:
 *    - The current system is basic - could be more sophisticated
 *    - Consider adding more sound types and variations
 *    - Add support for custom sound files and audio assets
 *    - Implement smart sound selection based on context
 * 
 * 2. AUDIO MANAGEMENT IMPROVEMENTS:
 *    - The current audio management could be enhanced
 *    - Add support for audio mixing and layering
 *    - Implement smart audio queuing and prioritization
 *    - Add support for audio fade-in/fade-out effects
 * 
 * 3. USER EXPERIENCE IMPROVEMENTS:
 *    - The current sound system could be more user-friendly
 *    - Add support for sound customization and preferences
 *    - Implement smart sound recommendations
 *    - Add support for sound tutorials and guidance
 * 
 * 4. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add support for audio description and narration
 *    - Implement audio accessibility features
 *    - Add support for different accessibility needs
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient audio loading and caching
 *    - Add support for background audio processing
 *    - Implement smart audio resource management
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for sound logic
 *    - Test different sound scenarios and edge cases
 *    - Add integration tests with real audio playback
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for sound features
 *    - Document the different sound types and usage patterns
 *    - Add examples of how to use different sounds
 *    - Create sound usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new sound types
 *    - Add support for custom sound configurations
 *    - Implement sound plugins
 *    - Add support for third-party audio integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Sound effects: Audio feedback that makes interactions feel more engaging
 * - AVFoundation: Apple's framework for audio and video processing
 * - Audio session: Managing how the app handles audio playback
 * - User experience: Making sure the app feels engaging and rewarding
 * - Accessibility: Ensuring the app works for users with different needs
 * - Audio feedback: Providing users with information through sound
 * - Sound queuing: Managing multiple sounds to prevent audio conflicts
 * - User preferences: Allowing users to customize their experience
 * - Performance: Making sure audio doesn't slow down the app
 * - Design systems: Standardized approaches to creating consistent experiences
 */

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
