//
//  AchievementCelebrationCoordinator.swift
//  StreakSync
//
//  Manages the presentation of achievement unlock celebrations
//

import SwiftUI
import UIKit
import OSLog

// MARK: - Achievement Celebration Coordinator
@MainActor
@Observable
final class AchievementCelebrationCoordinator {
    
    // MARK: - Observable Properties
    var currentCelebration: AchievementUnlock?
    var isShowingCelebration = false
    
    // MARK: - Private Properties
    @ObservationIgnored private var celebrationQueue: [AchievementUnlock] = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.streaksync.app", category: "AchievementCelebration")
    
    // MARK: - Queue Management Properties
    @ObservationIgnored private var processedAchievements: Set<String> = []
    @ObservationIgnored private let processedKey = "processedTieredAchievementsCache"
    @ObservationIgnored private let processedExpiryHours: Double = 24
    @ObservationIgnored private var isProcessingQueue = false
    @ObservationIgnored private var resumeObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    init() {
        loadProcessedCache()
    }
    
    // MARK: - Queue Management
    func queueCelebration(_ unlock: AchievementUnlock) {
        let achievementId = "\(unlock.achievement.id)-\(unlock.tier.rawValue)"

        if processedAchievements.contains(achievementId) {
            logger.info("🚫 Skipping duplicate celebration: \(unlock.achievement.displayName) - \(unlock.tier.displayName)")
            return
        }

        logger.info("🎊 Queueing celebration for \(unlock.achievement.displayName) - \(unlock.tier.displayName)")

        celebrationQueue.append(unlock)
        
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
        
        if UIApplication.shared.applicationState != .active {
            logger.info("🔇 Suppressing celebrations while app not active; will resume on activation")
            celebrationQueue.insert(nextUnlock, at: 0)
            isProcessingQueue = false
            
            if resumeObserver == nil {
                resumeObserver = NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        guard let self = self else { return }
                        if let token = self.resumeObserver {
                            NotificationCenter.default.removeObserver(token)
                            self.resumeObserver = nil
                        }
                        self.processCelebrationQueue()
                    }
                }
            }
            return
        }
        
        logger.info("🎉 Showing celebration for \(nextUnlock.achievement.displayName) - \(nextUnlock.tier.displayName)")
        
        let achievementId = "\(nextUnlock.achievement.id)-\(nextUnlock.tier.rawValue)"
        processedAchievements.insert(achievementId)
        persistProcessedCache()

        currentCelebration = nextUnlock
        isShowingCelebration = true
    }
    
    func dismissCurrentCelebration() {
        logger.info("👋 Dismissing current celebration")
        
        isShowingCelebration = false
        currentCelebration = nil
        
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
    
    // MARK: - Binding Helper
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
    @Bindable var coordinator: AchievementCelebrationCoordinator
    
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
