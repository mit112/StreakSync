//
//  AchievementCelebrationCoordinator.swift
//  StreakSync
//
//  Manages the presentation of achievement unlock celebrations
//

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
