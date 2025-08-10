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
    
    // MARK: - Initialization
    init() {
        setupObserver()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Setup
    private func setupObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("TieredAchievementUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let unlock = notification.object as? AchievementUnlock else { return }
            Task { @MainActor in
                self?.queueCelebration(unlock)
            }
        }
        
        logger.info("✅ Achievement celebration coordinator initialized")
    }
    
    // MARK: - Queue Management
    private func queueCelebration(_ unlock: AchievementUnlock) {
        logger.info("🎊 Queueing celebration for \(unlock.achievement.displayName) - \(unlock.tier.displayName)")
        
        celebrationQueue.append(unlock)
        
        // If not currently showing, start showing celebrations
        if !isShowingCelebration {
            showNextCelebration()
        }
    }
    
    private func showNextCelebration() {
        guard !celebrationQueue.isEmpty else {
            logger.info("✅ All celebrations completed")
            return
        }
        
        let nextUnlock = celebrationQueue.removeFirst()
        logger.info("🎉 Showing celebration for \(nextUnlock.achievement.displayName)")
        
        currentCelebration = nextUnlock
        isShowingCelebration = true
    }
    
    func dismissCurrentCelebration() {
        logger.info("👋 Dismissing current celebration")
        
        isShowingCelebration = false
        currentCelebration = nil
        
        // Show next celebration if any
        if !celebrationQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showNextCelebration()
            }
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
