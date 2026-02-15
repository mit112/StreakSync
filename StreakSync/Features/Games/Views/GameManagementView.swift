//
//  GameManagementView.swift
//  StreakSync
//
//  Simple game management with archive and reorder
//

import SwiftUI

struct GameManagementView: View {
    @Environment(AppState.self) private var appState
    @Environment(GameCatalog.self) private var gameCatalog
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject private var managementState: GameManagementState
    @State private var showingArchived = false
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    
    // Ordered games based on custom order
    var orderedGames: [Game] {
        let games = showingArchived ?
        appState.games.filter { managementState.isArchived($0.id) } :
        appState.games.filter { !managementState.isArchived($0.id) }
        
        return managementState.orderedGames(from: games)
    }
    
    // Filtered games based on search
    var filteredGames: [Game] {
        if searchText.isEmpty {
            return orderedGames
        } else {
            return orderedGames.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar (hide in archived view)
            if !showingArchived {
                searchBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Games list
            List {
                ForEach(filteredGames) { game in
                    GameManagementRow(
                        game: game,
                        isArchived: managementState.isArchived(game.id)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            managementState.toggleArchived(for: game.id)
                            HapticManager.shared.trigger(.toggleSwitch)
                        } label: {
                            Label(
                                managementState.isArchived(game.id) ? "Unarchive" : "Archive",
                                systemImage: managementState.isArchived(game.id) ? "tray.and.arrow.up" : "archivebox"
                            )
                        }
                        .tint(managementState.isArchived(game.id) ? .blue : .orange)
                    }
                }
                .onMove { source, destination in
                    moveGames(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
        }
        .navigationTitle(showingArchived ? "Archived Games" : "Manage Games")
        .navigationBarTitleDisplayMode(.inline)
        // Removed .navigationBarBackButtonHidden(true) to enable swipe back
        .toolbar {
            toolbarContent
        }
        .onAppear {
            managementState.reorderGames(appState.games)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingArchived)
    }
    
    // MARK: - Helper Methods
    private func moveGames(from source: IndexSet, to destination: Int) {
        // Get current order
        var gameIds = filteredGames.map { $0.id }
        
        // Move in local array
        gameIds.move(fromOffsets: source, toOffset: destination)
        
        // Update full game order
        var newOrder = managementState.gameOrder
        
        // Remove all filtered game IDs from the order
        filteredGames.forEach { game in
            newOrder.removeAll { $0 == game.id }
        }
        
        // Insert them back in the new order at the appropriate position
        if let firstIndex = managementState.gameOrder.firstIndex(where: { id in
            filteredGames.contains { $0.id == id }
        }) {
            newOrder.insert(contentsOf: gameIds, at: firstIndex)
        } else {
            newOrder.append(contentsOf: gameIds)
        }
        
        managementState.gameOrder = newOrder
        managementState.saveGameOrder()
        HapticManager.impact(.light)
    }
    
    
    // MARK: - Subviews
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search games", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if showingArchived {
                // Archived view - just show Done button
                Button("Done") {
                    dismiss()
                }
            } else {
                // Main view - combined menu
                Menu {
                    // Edit/Done option
                    Button {
                        withAnimation {
                            editMode = editMode == .inactive ? .active : .inactive
                        }
                    } label: {
                        Label(
                            editMode == .inactive ? "Edit" : "Done Editing",
                            systemImage: editMode == .inactive ? "pencil" : "checkmark"
                        )
                    }
                    
                    Divider()
                    
                    // View archived option
                    Button {
                        withAnimation {
                            showingArchived = true
                        }
                    } label: {
                        Label(
                            "View Archived (\(managementState.archivedGameIds.count))",
                            systemImage: "archivebox"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}


// MARK: - Game Row
struct GameManagementRow: View {
    let game: Game
    let isArchived: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                .font(.title2)
                .foregroundStyle(game.backgroundColor.color)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(game.backgroundColor.color.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(game.backgroundColor.color.opacity(0.3), lineWidth: 1)
                        )
                )
                .opacity(isArchived ? 0.6 : 1.0)
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(game.displayName)
                    .font(.headline)
                    .foregroundStyle(isArchived ? .secondary : .primary)
                    .strikethrough(isArchived)
                
                HStack(spacing: 6) {
                    Text(game.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray5))
                        )
                    
                    if isArchived {
                        Text("Archived")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.orange)
                            )
                    }
                }
            }
            
            Spacer()
            
            // Archive indicator
            if isArchived {
                Image(systemName: "archivebox.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
                .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
        }
    }
}
