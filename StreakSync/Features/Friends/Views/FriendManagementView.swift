//
//  FriendManagementView.swift
//  StreakSync
//
//  Manage friends — generate code, add by code, accept requests, remove friends.
//

import SwiftUI

@MainActor
struct FriendManagementView: View {
    let socialService: SocialService
    /// Bumps whenever the friendship listener (owned by `FriendsViewModel`) fires.
    /// Observed via `.onChange` to refresh local state without opening a second
    /// Firestore listener of our own.
    var friendshipChangeTick: Int = 0
    var initialJoinCode: String?

    @State private var friends: [UserProfile] = []
    @State private var pendingRequests: [Friendship] = []
    @State private var requesterNames: [String: String] = [:]
    @State private var myFriendCode: String?
    @State private var addCode: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var copiedCode: Bool = false
    @State private var pendingScoreCount: Int = 0
    @State private var friendToRemove: UserProfile?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                myCodeSection
                addFriendSection
                pendingRequestsSection
                friendsSection
                syncStatusSection
            }
            .navigationTitle("Manage Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if isLoading { ProgressView() }
                }
            }
            .task {
                await load()
                if let code = initialJoinCode, !code.isEmpty {
                    addCode = code
                    await addFriendByCode()
                }
            }
            // Live friendship updates come via FriendsViewModel's single listener;
            // we just react to its tick counter to keep this sheet's local state fresh.
            .onChange(of: friendshipChangeTick) { _, _ in
                Task { await loadFriendshipState() }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
// MARK: - Sections

private extension FriendManagementView {
    var myCodeSection: some View {
        Section {
            if let code = myFriendCode {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Friend Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(code)
                            .font(.title2.monospaced().weight(.bold))
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = code
                        copiedCode = true
                        Task { try? await Task.sleep(nanoseconds: 2_000_000_000); copiedCode = false }
                    } label: {
                        Label(copiedCode ? "Copied!" : "Copy", systemImage: copiedCode ? "checkmark" : "doc.on.doc")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedCode ? .green : .blue)
                }
            } else {
                Button("Generate Friend Code") {
                    Task { await generateCode() }
                }
            }
        } header: {
            Text("Share Your Code")
        } footer: {
            Text("Share this code with friends so they can add you.")
        }
    }

    var addFriendSection: some View {
        Section {
            TextField("Enter friend code", text: $addCode)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await addFriendByCode() }
            } label: {
                HStack {
                    Spacer()
                    Text("Add Friend")
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(addCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            if let msg = successMessage {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
        } header: {
            Text("Add a Friend")
        }
    }

    @ViewBuilder
    var pendingRequestsSection: some View {
        if !pendingRequests.isEmpty {
            Section("Pending Requests") {
                ForEach(pendingRequests) { request in
                    HStack {
                        Label(requesterNames[request.userId1] ?? "Someone", systemImage: "person.badge.clock")
                            .lineLimit(1)
                        Spacer()
                        Button("Accept") {
                            Task { await acceptRequest(request) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var friendsSection: some View {
        Section("Friends (\(friends.count))") {
            if friends.isEmpty {
                Text("No friends yet. Share your code or enter a friend's code above.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friends) { friend in
                    Label(friend.displayName, systemImage: "person.fill")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                friendToRemove = friend
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
                }
            }
        }
        .confirmationDialog(
            "Remove Friend",
            isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),
            titleVisibility: .visible
        ) {
            if let friend = friendToRemove {
                Button("Remove \(friend.displayName)", role: .destructive) {
                    Task { await removeFriend(friend) }
                }
            }
            Button("Cancel", role: .cancel) { friendToRemove = nil }
        } message: {
            if let friend = friendToRemove {
                Text("\(friend.displayName) will no longer see your scores, and you won't see theirs.")
            }
        }
    }

    var syncStatusSection: some View {
        Section("Sync Status") {
            HStack(spacing: 12) {
                if pendingScoreCount > 0 {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Syncing Scores...")
                            .font(.subheadline.weight(.medium))
                        Text("\(pendingScoreCount) score\(pendingScoreCount == 1 ? "" : "s") waiting")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scores Synced")
                            .font(.subheadline.weight(.medium))
                        Text("Your results appear on the leaderboard")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Actions

private extension FriendManagementView {
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await socialService.listFriends()
            pendingRequests = try await socialService.pendingRequests()
            pendingScoreCount = socialService.pendingScoreCount
            myFriendCode = try? await socialService.generateFriendCode()
            // Resolve display names from the friendship document (no profile read needed)
            var names: [String: String] = [:]
            for request in pendingRequests {
                names[request.userId1] = request.senderDisplayName ?? "Player"
            }
            requesterNames = names
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateCode() async {
        do {
            myFriendCode = try await socialService.generateFriendCode()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFriendByCode() async {
        let code = addCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        successMessage = nil
        do {
            guard let found = try await socialService.lookupByFriendCode(code) else {
                errorMessage = "No user found with that code."
                return
            }
            let autoAccepted = try await socialService.sendFriendRequest(
                toUserId: found.id,
                recipientDisplayName: found.displayName
            )
            addCode = ""
            if autoAccepted {
                successMessage = "You're now friends with \(found.displayName)!"
            } else {
                successMessage = "Friend request sent to \(found.displayName)!"
            }
            // Refresh lists
            friends = try await socialService.listFriends()
            pendingRequests = try await socialService.pendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(_ request: Friendship) async {
        do {
            try await socialService.acceptFriendRequest(friendshipId: request.id)
            friends = try await socialService.listFriends()
            pendingRequests = try await socialService.pendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friend: UserProfile) async {
        do {
            try await socialService.removeFriend(userId: friend.id)
            friends = try await socialService.listFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reload only the friendship-driven state (friends list + pending requests),
    /// leaving the user's typed input (addCode, success/error messages) intact.
    func loadFriendshipState() async {
        do {
            let newFriends = try await socialService.listFriends()
            let newPending = try await socialService.pendingRequests()
            friends = newFriends
            pendingRequests = newPending
            var names: [String: String] = [:]
            for request in newPending {
                names[request.userId1] = request.senderDisplayName ?? "Player"
            }
            requesterNames = names
        } catch {
            // Listener-driven refresh; keep the previous snapshot on error rather
            // than blanking the UI or surfacing a transient error to the user.
        }
    }

}
