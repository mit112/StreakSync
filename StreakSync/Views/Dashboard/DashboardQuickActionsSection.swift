//
//  DashboardQuickActionsSection.swift
//  StreakSync
//
//  Quick actions section for dashboard
//

import SwiftUI

struct DashboardQuickActionsSection: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var showingManualEntry = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: NSLocalizedString("dashboard.quick_actions", comment: "Quick Actions"),
                icon: "bolt.fill"
            )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: NSLocalizedString("action.add_game", comment: "Add Game"),
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    coordinator.presentSheet(.addCustomGame)
                }
                
                QuickActionButton(
                    title: NSLocalizedString("action.manual_entry", comment: "Manual Entry"),
                    icon: "keyboard.fill",
                    color: .purple
                ) {
                    showingManualEntry = true
                }
                
                QuickActionButton(
                    title: NSLocalizedString("action.all_streaks", comment: "All Streaks"),
                    icon: "list.bullet",
                    color: .green
                ) {
                    coordinator.navigateTo(.allStreaks)
                }
                
                QuickActionButton(
                    title: NSLocalizedString("action.achievements", comment: "Achievements"),
                    icon: "trophy.fill",
                    color: .yellow
                ) {
                    coordinator.navigateTo(.achievements)
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
    }
}

// MARK: - Preview
#Preview {
    DashboardQuickActionsSection()
        .environment(NavigationCoordinator())
        .padding()
}
