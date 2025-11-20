//
//  ContactsPermissionManager.swift
//  StreakSync
//
//  Handles Contacts permission prompts for friend discovery.
//

import Contacts

struct ContactsPermissionManager {
    enum Status {
        case notDetermined
        case restricted
        case denied
        case authorized
        case limited
    }
    
    func currentStatus() -> Status {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        case .limited: return .limited
        @unknown default: return .restricted
        }
    }
    
    func requestAccessIfNeeded() async -> Status {
        let status = currentStatus()
        guard status == .notDetermined else { return status }
        return await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted ? .authorized : .denied)
            }
        }
    }
}

