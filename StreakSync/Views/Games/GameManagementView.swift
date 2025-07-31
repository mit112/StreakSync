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
                        isArchived: managementState.isArchived(game.id),
                        onArchiveToggle: {
                            managementState.toggleArchived(for: game.id)
                            HapticManager.shared.trigger(.toggleSwitch)
                        }
                    )
                }
                .onMove { source, destination in
                    moveGames(from: source, to: destination)
                }
                .onDelete { indexSet in
                    archiveGames(at: indexSet)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
        }
        .background(Color(.systemGroupedBackground))
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
    
    private func archiveGames(at indexSet: IndexSet) {
        let gamesToArchive = indexSet.map { filteredGames[$0].id }
        for gameId in gamesToArchive {
            managementState.toggleArchived(for: gameId)
        }
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
    let onArchiveToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: game.iconSystemName)
                .font(.title2)
                .foregroundStyle(game.backgroundColor.color)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(game.backgroundColor.color.opacity(0.1))
                )
                .opacity(isArchived ? 0.6 : 1.0)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.displayName)
                    .font(.headline)
                    .strikethrough(isArchived)
                
                HStack(spacing: 4) {
                    Text(game.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if isArchived {
                        Text("• Archived")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            Menu {
                Button {
                    onArchiveToggle()
                } label: {
                    Label(
                        isArchived ? "Unarchive" : "Archive",
                        systemImage: isArchived ? "tray.and.arrow.up" : "archivebox"
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
