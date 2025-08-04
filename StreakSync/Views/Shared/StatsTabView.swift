//
//  StatsTabView.swift
//  StreakSync
//
//  Stats tab root view
//

import SwiftUI

struct StatsTabView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    var body: some View {
        AllStreaksView()
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
    }
}
