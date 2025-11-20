//
//  FriendDiscoveryView.swift
//  StreakSync
//

import SwiftUI

struct FriendDiscoveryView: View {
    @StateObject private var viewModel: FriendDiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var betaFlags: BetaFeatureFlags
    
    init(socialService: SocialService) {
        _viewModel = StateObject(wrappedValue: FriendDiscoveryViewModel(socialService: socialService))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isDiscoveryAvailable {
                    List {
                        introSection
                        permissionsSection
                        discoveredFriendsSection
                        if viewModel.isUsernameAdditionEnabled {
                            manualAddSection
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "icloud.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(betaFlags.contactDiscovery ? "Friend discovery requires iCloud on this device." : "Friend discovery is disabled in this beta build.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Close") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Find Friends")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await viewModel.initialize()
            }
            .alert(isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
                Alert(title: Text("Friend Discovery"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
            }
        }
    }
}

private extension FriendDiscoveryView {
    var introSection: some View {
        Section("How it works") {
            Text("StreakSync matches your contacts with friends who also use the app. Nobody sees your contacts, and you choose who to add.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    var permissionsSection: some View {
        Section("Permissions") {
            HStack {
                Label("Contacts access", systemImage: "person.crop.circle.badge.questionmark")
                Spacer()
                Text(statusDescription(for: viewModel.contactsStatus))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("iCloud discoverability", systemImage: "icloud")
                Spacer()
                Text(discoverabilityDescription(for: viewModel.discoverabilityStatus))
                    .foregroundStyle(.secondary)
            }
            Button("Allow & Find Friends") {
                Task { await viewModel.requestPermissionsAndDiscover() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    var discoveredFriendsSection: some View {
        Section("Discovered Friends") {
            if viewModel.discoveredFriends.isEmpty {
                Text("No contacts matched yet. Tap “Allow & Find Friends” after enabling permissions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.discoveredFriends) { friend in
                    VStack(alignment: .leading) {
                        Text(friend.displayName)
                            .font(.headline)
                        Text(friend.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    var manualAddSection: some View {
        Section("Add by username") {
            TextField("friend@icloud", text: $viewModel.manualUsername)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            Button("Add") {
                Task { await viewModel.addFriendByUsername() }
            }
            .disabled(viewModel.manualUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    func statusDescription(for status: ContactsPermissionManager.Status) -> String {
        switch status {
        case .authorized: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not yet asked"
        case .limited: return "Limited"
        }
    }
    
    func discoverabilityDescription(for status: CloudKitDiscoverabilityManager.Status) -> String {
        switch status {
        case .granted: return "Enabled"
        case .denied: return "Denied"
        case .notDetermined: return "Not yet asked"
        case .unavailable: return "Unavailable"
        }
    }
}

