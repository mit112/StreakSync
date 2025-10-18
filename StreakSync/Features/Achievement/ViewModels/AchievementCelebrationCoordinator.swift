//
//  AchievementCelebrationCoordinator.swift
//  StreakSync
//
//  Manages the presentation of achievement unlock celebrations
//

/*
 * ACHIEVEMENTCELEBRATIONCOORDINATOR - ACHIEVEMENT UNLOCK CELEBRATION MANAGER
 * 
 * WHAT THIS FILE DOES:
 * This file manages the presentation of achievement unlock celebrations, ensuring
 * that users get proper recognition and feedback when they unlock achievements.
 * It's like a "celebration manager" that handles the timing, queuing, and display
 * of achievement celebrations. Think of it as the "achievement celebration system"
 * that makes unlocking achievements feel rewarding and engaging for users.
 * 
 * WHY IT EXISTS:
 * Users need to feel rewarded and recognized when they unlock achievements. This
 * coordinator ensures that achievement celebrations are shown at the right time,
 * in the right order, and with proper visual and audio feedback. It prevents
 * celebration spam and ensures a smooth, engaging user experience.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This makes achievements feel rewarding and engaging
 * - Manages achievement celebration timing and queuing
 * - Prevents celebration spam and overlapping celebrations
 * - Provides proper visual and audio feedback for achievements
 * - Ensures celebrations are shown at appropriate times
 * - Handles celebration persistence and caching
 * - Coordinates with the achievement system for seamless integration
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI presentation and state management
 * - OSLog: For logging and debugging
 * - NotificationCenter: For listening to achievement unlock notifications
 * - AchievementUnlock: Achievement unlock data and information
 * - AppConstants: For notification names and constants
 * 
 * WHAT REFERENCES IT:
 * - Achievement system: Posts notifications that this coordinator listens to
 * - AppContainer: Creates and manages this coordinator
 * - Achievement views: Use this for celebration display
 * - Various feature views: Can trigger achievement celebrations
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. CELEBRATION MANAGEMENT IMPROVEMENTS:
 *    - The current celebration system is good but could be more sophisticated
 *    - Consider adding more celebration types and animations
 *    - Add support for custom celebration configurations
 *    - Implement smart celebration timing based on user behavior
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current celebrations could be more engaging
 *    - Add support for celebration customization and preferences
 *    - Implement smart celebration recommendations
 *    - Add support for celebration tutorials and guidance
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient celebration rendering
 *    - Add support for celebration caching and reuse
 *    - Implement smart celebration management
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add comprehensive tests for celebration logic
 *    - Test different celebration scenarios and edge cases
 *    - Add UI tests for celebration interactions
 *    - Test celebration timing and queuing
 * 
 * 5. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for celebration features
 *    - Document the different celebration types and usage patterns
 *    - Add examples of how to use different celebrations
 *    - Create celebration usage guidelines
 * 
 * 6. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new celebration types
 *    - Add support for custom celebration configurations
 *    - Implement celebration plugins
 *    - Add support for third-party celebration integrations
 * 
 * 7. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add support for accessibility-enhanced celebrations
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for celebration interactions
 *    - Implement metrics for celebration effectiveness
 *    - Add support for celebration debugging
 *    - Monitor celebration performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Celebration systems: Making achievements feel rewarding and engaging
 * - User experience: Making sure users feel recognized and motivated
 * - Notification handling: Listening for events and responding appropriately
 * - Queue management: Handling multiple events in the right order
 * - State management: Managing celebration state and presentation
 * - User engagement: Keeping users interested and motivated
 * - Visual feedback: Providing clear information about user actions
 * - Audio feedback: Using sound to enhance user experience
 * - Performance: Making sure celebrations don't slow down the app
 * - Accessibility: Making sure celebrations work for all users
 */

import SwiftUI
import OSLog

// MARK: - Achievement Celebration Coordinator
@MainActor
final class AchievementCelebrationCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentCelebration: AchievementUnlock?
    @Published var isShowingCelebration = false
    
    // MARK: - Private Properties
    private var celebrationQueue: [AchievementUnlock] = []
    private var notificationObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AchievementCelebration")
    
    // MARK: - Queue Management Properties
    private var processedAchievements: Set<String> = []
    private let processedKey = "processedTieredAchievementsCache"
    private let processedExpiryHours: Double = 24
    private var isProcessingQueue = false
    
    // MARK: - Initialization
    init() {
        logger.info("🏗️ Initializing AchievementCelebrationCoordinator")
        loadProcessedCache()
        setupObserver()
        logger.info("✅ AchievementCelebrationCoordinator ready")
    }
    
    deinit {
        // Note: notificationObserver cleanup happens automatically
        // Cannot access mutable state in deinit under strict concurrency
    }
    
    // MARK: - Setup
    private func setupObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(AppConstants.Notification.tieredAchievementUnlocked),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let unlock = notification.object as? AchievementUnlock else { 
                self?.logger.warning("⚠️ Received invalid achievement unlock notification")
                return 
            }
            self?.logger.info("📨 Received achievement unlock notification: \(unlock.achievement.displayName)")
            Task { @MainActor in
                self?.queueCelebration(unlock)
            }
        }
        
        logger.info("✅ Achievement celebration coordinator initialized")
    }
    
    // MARK: - Queue Management
    private func queueCelebration(_ unlock: AchievementUnlock) {
        // Create unique identifier for this achievement unlock
        let achievementId = "\(unlock.achievement.id)-\(unlock.tier.rawValue)"
        
        // Prevent duplicate celebrations
        if processedAchievements.contains(achievementId) {
            logger.info("🚫 Skipping duplicate celebration: \(unlock.achievement.displayName) - \(unlock.tier.displayName)")
            return
        }
        
        logger.info("🎊 Queueing celebration for \(unlock.achievement.displayName) - \(unlock.tier.displayName)")
        
        // Mark as processed to prevent duplicates
        processedAchievements.insert(achievementId)
        persistProcessedCache()
        celebrationQueue.append(unlock)
        
        // If not currently showing, start showing celebrations
        if !isShowingCelebration && !isProcessingQueue {
            processCelebrationQueue()
        }
    }
    
    // MARK: - Persistence for dedup cache
    private func loadProcessedCache() {
        let defaults = UserDefaults.standard
        if let data = defaults.array(forKey: processedKey) as? [String] {
            processedAchievements = Set(data)
        }
        // Clear cache if older than expiry
        if let last = defaults.object(forKey: processedKey+"_ts") as? Date, Date().timeIntervalSince(last) > processedExpiryHours*3600 {
            processedAchievements.removeAll()
            defaults.removeObject(forKey: processedKey)
            defaults.removeObject(forKey: processedKey+"_ts")
        }
    }
    
    private func persistProcessedCache() {
        let defaults = UserDefaults.standard
        defaults.set(Array(processedAchievements), forKey: processedKey)
        defaults.set(Date(), forKey: processedKey+"_ts")
    }
    
    private func processCelebrationQueue() {
        guard !isProcessingQueue else {
            logger.info("🔄 Already processing celebration queue")
            return
        }
        
        isProcessingQueue = true
        showNextCelebration()
    }
    
    private func showNextCelebration() {
        guard !celebrationQueue.isEmpty else {
            logger.info("✅ All celebrations completed")
            isProcessingQueue = false
            return
        }
        
        let nextUnlock = celebrationQueue.removeFirst()
        logger.info("🎉 Showing celebration for \(nextUnlock.achievement.displayName) - \(nextUnlock.tier.displayName)")
        
        currentCelebration = nextUnlock
        isShowingCelebration = true
    }
    
    func dismissCurrentCelebration() {
        logger.info("👋 Dismissing current celebration")
        
        isShowingCelebration = false
        currentCelebration = nil
        
        // Show next celebration if any
        if !self.celebrationQueue.isEmpty {
            logger.info("⏭️ Showing next celebration in queue (\(self.celebrationQueue.count) remaining)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showNextCelebration()
            }
        } else {
            logger.info("🏁 Celebration queue completed")
            self.isProcessingQueue = false
        }
    }
    
    // MARK: - Public Methods
    func celebrationBinding() -> Binding<AchievementUnlock?> {
        Binding(
            get: { self.currentCelebration },
            set: { newValue in
                if newValue == nil {
                    self.dismissCurrentCelebration()
                }
            }
        )
    }
}

// MARK: - View Modifier
struct AchievementCelebrationModifier: ViewModifier {
    @ObservedObject var coordinator: AchievementCelebrationCoordinator
    
    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: coordinator.celebrationBinding()) { unlock in
                AchievementUnlockCelebrationView(
                    unlock: unlock,
                    celebrationCoordinator: coordinator
                )
            }
    }
}

// MARK: - View Extension
extension View {
    func achievementCelebrations(coordinator: AchievementCelebrationCoordinator) -> some View {
        modifier(AchievementCelebrationModifier(coordinator: coordinator))
    }
}
