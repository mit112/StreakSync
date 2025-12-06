//
//  FriendManagementView.swift
//  StreakSync
//

import SwiftUI

@MainActor
struct FriendManagementView: View {
    let socialService: SocialService
    @State private var friends: [UserProfile] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isCreatingGroup: Bool = false
    @State private var isJoiningGroup: Bool = false
    @State private var joinCode: String = ""
    @State private var activeCircle: SocialCircle?
    
    private var circleManager: CircleManaging? { socialService as? CircleManaging }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Friends") {
                    if friends.isEmpty {
                        Text("No friends yet. Friend discovery will automatically match contacts soon.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                                Text(friend.displayName)
                        }
                    }
                }
                
                // Sharing (Firebase join codes)
                Section("Friends Sharing") {
                    if let circle = activeCircle {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Sharing Enabled", systemImage: "person.3")
                                .font(.subheadline.weight(.semibold))
                            Text(circle.name)
                                .font(.subheadline.weight(.semibold))
                            Text(circle.id.uuidString)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Not sharing yet").font(.subheadline).foregroundStyle(.secondary)
                    }
                    
                    Button {
                        Task { await createCircle() }
                    } label: {
                        HStack {
                            if isCreatingGroup { ProgressView().scaleEffect(0.8) }
                            Text(isCreatingGroup ? "Creating..." : "Create Group & Join")
                        }
                    }
                    .disabled(isCreatingGroup)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Join code (e.g. AB7K2M)", text: $joinCode)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                        Button {
                            Task { await joinCircle() }
                        } label: {
                            HStack {
                                if isJoiningGroup { ProgressView().scaleEffect(0.8) }
                                Text("Join with Code")
                            }
                        }
                        .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoiningGroup)
                    }
                    
                    Text("Create a group to get a join code, then share it with friends. Everyone who joins sees and contributes to the same leaderboard.")
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
        }
    }
    
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await socialService.listFriends()
            if let circleManager {
                let circles = try await circleManager.listCircles()
                if let activeId = circleManager.activeCircleId,
                   let existing = circles.first(where: { $0.id == activeId }) {
                    activeCircle = existing
                } else {
                    activeCircle = circles.first
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }
    
    private func createCircle() async {
        guard let circleManager else { return }
        isCreatingGroup = true
        defer { isCreatingGroup = false }
        do {
            let circle = try await circleManager.createCircle(name: "Friends")
            activeCircle = circle
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func joinCircle() async {
        guard let circleManager else { return }
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isJoiningGroup = true
        defer { isJoiningGroup = false }
        do {
            let circle = try await circleManager.joinCircle(using: code)
            activeCircle = circle
            joinCode = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? { connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first }
}


