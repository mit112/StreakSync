//
//  DayChangeDetector.swift
//  StreakSync
//
//  Detects day changes and triggers UI updates automatically
//

import Foundation
import Combine
import UIKit

@MainActor
class DayChangeDetector: ObservableObject {
    static let shared = DayChangeDetector()
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Published property to trigger UI updates
    @Published var currentDay: String = ""
    
    private init() {
        setupDayChangeDetection()
    }
    
    deinit {
        Task { @MainActor in
            stopDayChangeDetection()
        }
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring for day changes
    func startMonitoring() {
        setupDayChangeDetection()
    }
    
    /// Stop monitoring for day changes
    func stopMonitoring() {
        stopDayChangeDetection()
    }
    
    /// Force a day change check (useful for testing)
    func checkForDayChange() {
        updateCurrentDay()
    }
    
    // MARK: - Private Methods
    
    private func setupDayChangeDetection() {
        // Stop any existing timer
        stopDayChangeDetection()
        
        // Set initial day
        updateCurrentDay()
        
        // Create timer that fires every minute to check for day changes
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForDayChange()
            }
        }
        
        // Also listen for app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkForDayChange()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkForDayChange()
                }
            }
            .store(in: &cancellables)
    }
    
    private func stopDayChangeDetection() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }
    
    private func updateCurrentDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let newDay = formatter.string(from: Date())
        
        // Only update if the day has actually changed
        if newDay != currentDay {
            let oldDay = currentDay
            currentDay = newDay
            
            // Log the day change
            print("📅 Day changed from \(oldDay) to \(newDay)")
            
            // Post notification for other parts of the app to respond
            NotificationCenter.default.post(
                name: .dayDidChange,
                object: nil,
                userInfo: [
                    "oldDay": oldDay,
                    "newDay": newDay
                ]
            )
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let dayDidChange = Notification.Name("dayDidChange")
}
