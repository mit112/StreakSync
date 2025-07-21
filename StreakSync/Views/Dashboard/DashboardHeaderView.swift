//
//  DashboardHeaderView.swift
//  StreakSync
//
//  Extracted header component from DashboardView
//

import SwiftUI

// MARK: - Dashboard Header
struct DashboardHeaderView: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return NSLocalizedString("greeting.morning", comment: "Good morning")
        case 12..<17:
            return NSLocalizedString("greeting.afternoon", comment: "Good afternoon")
        default:
            return NSLocalizedString("greeting.evening", comment: "Good evening")
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(NSLocalizedString("dashboard.title", comment: "Your Streaks"))
                    .font(.largeTitle.weight(.bold))
            }
            .accessibilityElement(children: .combine)
            
            Spacer()
            
            Button {
                coordinator.navigateTo(.settings)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(NSLocalizedString("settings.title", comment: "Settings"))
        }
    }
}

// MARK: - Today's Progress Card
struct TodaysProgressCard: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                
                Text(NSLocalizedString("dashboard.todays_progress", comment: "Today's Progress"))
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: NSLocalizedString("dashboard.completed_games", comment: "%d completed"),
                           appState.todaysResults.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if appState.todaysResults.count <= 5 {
                // Show individual results for small counts
                TodayResultsScrollView(results: appState.todaysResults)
            } else {
                // Show summary for large counts to maintain performance
                TodayResultsSummary(results: appState.todaysResults)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("dashboard.todays_progress", comment: "Today's Progress"))
    }
}

// MARK: - Preview
#Preview {
    DashboardHeaderView()
        .environment(AppState())
        .padding()
}
