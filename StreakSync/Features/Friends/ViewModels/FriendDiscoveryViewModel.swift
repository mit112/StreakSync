//
//  FriendDiscoveryViewModel.swift
//  StreakSync
//

import Foundation

@MainActor
final class FriendDiscoveryViewModel: ObservableObject {
    @Published var contactsStatus: ContactsPermissionManager.Status = .notDetermined
    @Published var discoverabilityStatus: CloudKitDiscoverabilityManager.Status = .notDetermined
    @Published var discoveredFriends: [DiscoveredFriend] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var manualUsername: String = ""
    
    private let discoveryProvider: FriendDiscoveryProviding?
    private let flags = BetaFeatureFlags.shared
    private let contactsManager = ContactsPermissionManager()
    private let discoverabilityManager = CloudKitDiscoverabilityManager()
    
    init(socialService: SocialService) {
        self.discoveryProvider = socialService as? FriendDiscoveryProviding
    }
    
    var isDiscoveryAvailable: Bool {
        flags.contactDiscovery && discoveryProvider != nil
    }
    
    var isUsernameAdditionEnabled: Bool {
        flags.usernameAddition
    }
    
    func initialize() async {
        guard flags.contactDiscovery else { return }
        contactsStatus = contactsManager.currentStatus()
        discoverabilityStatus = await discoverabilityManager.currentStatus()
        // Note: CKShare-based discovery doesn't require discoverability permission
        // Friends are discovered from existing shares automatically
        await refreshDiscoveries(force: false)
    }
    
    func requestPermissionsAndDiscover() async {
        guard flags.contactDiscovery else {
            errorMessage = "Contact discovery is disabled in this beta build."
            return
        }
        guard let discoveryProvider else {
            errorMessage = "Friend discovery requires signing into iCloud on this device."
            return
        }
        isLoading = true
        defer { isLoading = false }
        
        // CKShare-based discovery: No contacts or discoverability permission needed
        // Friends are automatically discovered from existing CKShare participants
        do {
            discoveredFriends = try await discoveryProvider.discoverFriends(forceRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshDiscoveries(force: Bool) async {
        guard flags.contactDiscovery, let discoveryProvider else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            discoveredFriends = try await discoveryProvider.discoverFriends(forceRefresh: force)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func addFriendByUsername() async {
        guard flags.usernameAddition else {
            errorMessage = "Adding friends by username is disabled in this beta build."
            return
        }
        guard let discoveryProvider else {
            errorMessage = "Friend discovery is currently unavailable."
            return
        }
        let username = manualUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await discoveryProvider.addFriend(usingUsername: username)
            manualUsername = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

