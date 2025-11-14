//
//  FriendManagementView.swift
//  StreakSync
//

import SwiftUI
import CloudKit

@MainActor
struct FriendManagementView: View {
    let socialService: SocialService
    @State private var myFriendCode: String = ""
    @State private var friends: [UserProfile] = []
    @State private var friendCodeToAdd: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @EnvironmentObject private var container: AppContainer
    // Shared Leaderboards (CKShare)
    @State private var isCreatingGroup: Bool = false
    @State private var createdShare: CKShare?
    @State private var showShareSheet: Bool = false
    @State private var activeGroupTitle: String = LeaderboardGroupStore.selectedGroupTitle ?? ""
    @State private var activeGroupIdText: String = LeaderboardGroupStore.selectedGroupId?.uuidString ?? ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Your Code") {
                    HStack(spacing: 12) {
                        Text(myFriendCode)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button("Copy") { HapticManager.shared.trigger(.achievement); UIPasteboard.general.string = myFriendCode }
                        Button("Share") {
                            let activityVC = UIActivityViewController(activityItems: [myFriendCode], applicationActivities: nil)
                            UIApplication.shared.firstKeyWindow?.rootViewController?.present(activityVC, animated: true)
                        }
                    }
                }
                Section("Add a Friend") {
                    TextField("Enter friend code", text: $friendCodeToAdd)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button("Add") { Task { await addFriend() } }
                        .disabled(friendCodeToAdd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Friends") {
                    if friends.isEmpty {
                        Text("No friends yet. Share your code to connect!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            HStack {
                                Text(friend.displayName)
                                Spacer()
                                Text(friend.friendCode)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Friends Sharing (CKShare)
                Section("Friends Sharing") {
                    if let gid = LeaderboardGroupStore.selectedGroupId {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Sharing Enabled", systemImage: "person.3")
                                Spacer()
                            }
                            Text(activeGroupTitle.isEmpty ? "Friends" : activeGroupTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(gid.uuidString)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        Button(role: .destructive) {
                            LeaderboardGroupStore.clearSelectedGroup()
                            activeGroupTitle = ""
                            activeGroupIdText = ""
                        } label: {
                            Label("Stop Sharing on this device", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        Text("You’ll stop receiving and publishing scores to the shared leaderboard on this device. Others keep access unless you revoke sharing in iCloud later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not sharing yet").font(.subheadline).foregroundStyle(.secondary)
                    }
                    
                    Button {
                        Task { await inviteFriends() }
                    } label: {
                        HStack {
                            if isCreatingGroup { ProgressView().scaleEffect(0.8) }
                            Text(isCreatingGroup ? "Preparing..." : "Invite Friends")
                        }
                    }
                    .disabled(isCreatingGroup)
                    Text("Shares your leaderboard with invited friends using iCloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Manage Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading { ProgressView() }
                }
            }
            .task { await load() }
            .alert(isPresented: .constant(errorMessage != nil), content: {
                Alert(title: Text("Error"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")) { errorMessage = nil })
            })
            .sheet(isPresented: $showShareSheet) {
                if let share = createdShare {
                    ShareInviteView(
                        share: share,
                        container: CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
                    )
                }
            }
        }
    }
    
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            myFriendCode = try await socialService.generateFriendCode()
            friends = try await socialService.listFriends()
        } catch { errorMessage = error.localizedDescription }
    }
    
    private func addFriend() async {
        guard !friendCodeToAdd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await socialService.addFriend(using: friendCodeToAdd)
            friendCodeToAdd = ""
            friends = try await socialService.listFriends()
        } catch { errorMessage = error.localizedDescription }
    }
    
    private func inviteFriends() async {
        isCreatingGroup = true
        defer { isCreatingGroup = false }
        do {
            let result = try await container.leaderboardSyncService.ensureFriendsShare()
            createdShare = result.share
            LeaderboardGroupStore.setSelectedGroup(id: result.groupId, title: "Friends")
            activeGroupTitle = "Friends"
            activeGroupIdText = result.groupId.uuidString
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? { connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first }
}


