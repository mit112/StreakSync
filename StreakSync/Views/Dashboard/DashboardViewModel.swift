//
//  DashboardViewModel.swift
//  Dashboard business logic with auto-refresh support
//

import SwiftUI
import OSLog

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var isRefreshing = false
    @Published var lastRefreshTime = Date()
    private weak var appState: AppState?
    private let logger = Logger(subsystem: "com.streaksync.app", category: "DashboardViewModel")
    
    // Add notification observers
    private var notificationObservers: [NSObjectProtocol] = []
    
    deinit {
        // Clean up observers
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    func setup(with appState: AppState) {
        self.appState = appState
        logger.debug("DashboardViewModel setup complete")
        
        // Listen for game result additions
        let resultObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GameResultAdded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDataUpdate()
        }
        notificationObservers.append(resultObserver)
        
        // Listen for data updates
        let dataObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GameDataUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDataUpdate()
        }
        notificationObservers.append(dataObserver)
        
        // Listen for game result received
        let receivedObserver = NotificationCenter.default.addObserver(
            forName: .gameResultReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDataUpdate()
        }
        notificationObservers.append(receivedObserver)
    }
    
    private func handleDataUpdate() {
        // Force a view update by changing published property
        lastRefreshTime = Date()
        logger.info("DashboardViewModel forcing UI refresh")
    }
    
    func refreshData() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshTime = Date() // Force UI update
        }
        
        // Refresh app state data
        if let appState = appState {
            await appState.refreshData()
        }
        
        // Simulate network delay for smooth UI
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        logger.info("Dashboard data refreshed")
    }
}
