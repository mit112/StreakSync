//
//  AppGroupDarwinNotificationHandler.swift
//  StreakSync
//
//  Handles Darwin notifications for cross-process communication
//

import Foundation
import OSLog

@MainActor
final class AppGroupDarwinNotificationHandler {
    // MARK: - Properties
    private let darwinNotificationName = "com.streaksync.app.newResult"
    private let logger = Logger(subsystem: "com.streaksync.app", category: "DarwinNotificationHandler")
    private var isObserving = false
    
    // MARK: - Callback
    private var onNotificationReceived: (() async -> Void)?
    
    // MARK: - Setup
    func startObserving(onNotificationReceived: @escaping () async -> Void) {
        guard !isObserving else { return }
        
        self.onNotificationReceived = onNotificationReceived
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, name, _, _ in
                guard let observer = observer else { return }
                let handler = Unmanaged<AppGroupDarwinNotificationHandler>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    await handler.handleDarwinNotification()
                }
            },
            darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
        
        isObserving = true
 logger.info("Started observing Darwin notifications")
    }
    
    func stopObserving() {
        guard isObserving else { return }
        
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        isObserving = false
        onNotificationReceived = nil
 logger.info("Stopped observing Darwin notifications")
    }
    
    // MARK: - Private Methods
    private func handleDarwinNotification() async {
 logger.info("Received Darwin notification for new result")
        await onNotificationReceived?()
    }
    
    deinit {
        // Safe to call from deinit since Darwin notification center operations are thread-safe
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
