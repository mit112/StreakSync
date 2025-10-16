//
//  FriendManagementView.swift
//  StreakSync
//

import SwiftUI

@MainActor
struct FriendManagementView: View {
    let socialService: SocialService
    @State private var myFriendCode: String = ""
    @State private var friends: [UserProfile] = []
    @State private var friendCodeToAdd: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
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
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? { connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first }
}


