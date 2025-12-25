//
//  FriendManagementView.swift
//  StreakSync
//
//  Simplified friends management - one group per user.
//

import SwiftUI

@MainActor
struct FriendManagementView: View {
    let socialService: SocialService
    /// Optional initial join code from deep link
    var initialJoinCode: String? = nil
    
    @State private var friends: [UserProfile] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isCreatingGroup: Bool = false
    @State private var isJoiningGroup: Bool = false
    @State private var isLeavingGroup: Bool = false
    @State private var joinCode: String = ""
    @State private var activeGroup: SocialCircle?
    @State private var showLeaveConfirmation: Bool = false
    @State private var copiedCode: Bool = false
    @State private var pendingScoreCount: Int = 0
    @State private var hasAppliedInitialCode: Bool = false
    @State private var showShareSheet: Bool = false
    
    private var circleManager: CircleManaging? { socialService as? CircleManaging }
    
    /// Whether the user already has a friends group
    private var hasGroup: Bool { activeGroup != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // Friends list section
                Section("Friends") {
                    if !hasGroup {
                        Text("Join or create a friends group to see your friends here.")
                            .foregroundStyle(.secondary)
                    } else if friends.isEmpty {
                        Text("No friends in your group yet. Share your join code to invite friends!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            Label(friend.displayName, systemImage: "person.fill")
                        }
                    }
                }
                
                // Friends Group section
                if let group = activeGroup {
                    // User HAS a group - show info and leave option
                    activeGroupSection(group)
                    
                    // Sync status section
                    syncStatusSection
                } else {
                    // User has NO group - show create/join options
                    noGroupSection
                }
            }
            .navigationTitle("Manage Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading { ProgressView() }
                }
            }
            .task { 
                await load()
                // Apply initial join code from deep link (only once)
                if let code = initialJoinCode, !code.isEmpty, !hasAppliedInitialCode {
                    hasAppliedInitialCode = true
                    joinCode = code
                    // Auto-join if user doesn't have a group
                    if activeGroup == nil {
                        await joinGroup()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Leave Friends Group?", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    Task { await leaveGroup() }
                }
            } message: {
                Text("You'll no longer see scores from this group. You can join another group or create a new one.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let code = activeGroup?.joinCode {
                    ShareSheet(activityItems: [shareMessage(for: code)])
                }
            }
        }
    }
    
    // MARK: - Share Message
    
    private func shareMessage(for code: String) -> String {
        """
        🎮 Join my StreakSync friends group!
        
        Compare daily scores on Wordle, Connections, and more.
        
        Tap to join: streaksync://join?code=\(code)
        
        Or enter code: \(code)
        """
    }
    
    // MARK: - Active Group Section (User has a group)
    
    @ViewBuilder
    private func activeGroupSection(_ group: SocialCircle) -> some View {
        Section {
            // Group status
            VStack(alignment: .leading, spacing: 8) {
                Label("Friends Group Active", systemImage: "person.3.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                
                Text("\(group.members.count) member\(group.members.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            
            // Join code with copy and share buttons
            if let code = group.joinCode {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Join Code")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(code)
                                .font(.title2.monospaced().weight(.bold))
                        }
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = code
                            copiedCode = true
                            
                            // Reset after 2 seconds
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                copiedCode = false
                            }
                        } label: {
                            Label(copiedCode ? "Copied!" : "Copy", systemImage: copiedCode ? "checkmark" : "doc.on.doc")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .tint(copiedCode ? .green : .blue)
                    }
                    
                    // Share button - opens native share sheet with deep link
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Invite Friends", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }
            
            // Share instructions
            Text("Share this code with friends so they can join your group and compare scores on the leaderboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Friends Group")
        }
        
        // Leave group option
        Section {
            Button(role: .destructive) {
                showLeaveConfirmation = true
            } label: {
                HStack {
                    if isLeavingGroup {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(isLeavingGroup ? "Leaving..." : "Leave Friends Group")
                }
            }
            .disabled(isLeavingGroup)
        } footer: {
            Text("Leave this group to join or create a different one.")
        }
    }
    
    // MARK: - Sync Status Section
    
    @ViewBuilder
    private var syncStatusSection: some View {
        Section {
            HStack(spacing: 12) {
                if pendingScoreCount > 0 {
                    // Pending sync
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Syncing Scores...")
                            .font(.subheadline.weight(.medium))
                        Text("\(pendingScoreCount) score\(pendingScoreCount == 1 ? "" : "s") waiting to upload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // All synced
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scores Synced")
                            .font(.subheadline.weight(.medium))
                        Text("Your game results appear on the leaderboard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Sync Status")
        }
    }
    
    // MARK: - No Group Section (User needs to create/join)
    
    @ViewBuilder
    private var noGroupSection: some View {
        Section {
            // Create new group
            Button {
                Task { await createGroup() }
            } label: {
                HStack {
                    Label(isCreatingGroup ? "Creating..." : "Create Friends Group", 
                          systemImage: "plus.circle.fill")
                    Spacer()
                    if isCreatingGroup {
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .disabled(isCreatingGroup)
            
            // OR divider
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .listRowBackground(Color.clear)
            
            // Join existing group
            VStack(alignment: .leading, spacing: 10) {
                Text("Join a Friend's Group")
                    .font(.subheadline.weight(.medium))
                
                TextField("Enter join code (e.g. AB7K2M)", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    Task { await joinGroup() }
                } label: {
                    HStack {
                        Spacer()
                        if isJoiningGroup {
                            ProgressView().scaleEffect(0.8)
                        }
                        Text(isJoiningGroup ? "Joining..." : "Join Group")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoiningGroup)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Friends Group")
        } footer: {
            Text("Create a group to get a join code, or enter a friend's code to join their group. Everyone in a group shares scores on the same leaderboard.")
        }
    }
    
    // MARK: - Actions
    
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let circleManager {
                let circles = try await circleManager.listCircles()
                // Use the first group (we only support one)
                if let activeId = circleManager.activeCircleId,
                   let existing = circles.first(where: { $0.id == activeId }) {
                    activeGroup = existing
                } else {
                    activeGroup = circles.first
                }
            }
            
            // Only fetch friends if we have a group
            if activeGroup != nil {
                friends = try await socialService.listFriends()
            }
            
            // Update sync status
            pendingScoreCount = socialService.pendingScoreCount
        } catch { 
            errorMessage = error.localizedDescription 
        }
    }
    
    private func createGroup() async {
        guard let circleManager else { return }
        isCreatingGroup = true
        defer { isCreatingGroup = false }
        do {
            let group = try await circleManager.createCircle(name: "Friends")
            activeGroup = group
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func joinGroup() async {
        guard let circleManager else { return }
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isJoiningGroup = true
        defer { isJoiningGroup = false }
        do {
            let group = try await circleManager.joinCircle(using: code)
            activeGroup = group
            joinCode = ""
            // Reload friends after joining
            friends = try await socialService.listFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func leaveGroup() async {
        guard let circleManager, let group = activeGroup else { return }
        isLeavingGroup = true
        defer { isLeavingGroup = false }
        do {
            try await circleManager.leaveCircle(id: group.id)
            activeGroup = nil
            friends = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


