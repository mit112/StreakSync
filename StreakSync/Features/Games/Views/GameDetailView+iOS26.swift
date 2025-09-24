//
//  GameDetailView+iOS26.swift
//  StreakSync
//
//  SIMPLIFIED iOS 26 Extensions for GameDetailView
//

import SwiftUI

// MARK: - iOS 26 Hero Animation Support
@available(iOS 26.0, *)
extension GameDetailView {
    
    /// iOS 26 version with modern transitions (SIMPLIFIED)
    var iOS26Body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Standard header - no hero stuff needed
                GameDetailHeader(
                    game: game,
                    streak: viewModel.currentStreak
                )
                .staggeredAppearance(index: 0, totalCount: 4)
                
                // Primary Actions
                GameDetailPrimaryActions(
                    game: game,
                    showingManualEntry: $showingManualEntry,
                    isLoadingGame: $isLoadingGame,
                    onPlayGame: playGame
                )
                .staggeredAppearance(index: 1, totalCount: 4)
                
                // Performance Section
                if !viewModel.recentResults.isEmpty {
                    GameDetailPerformanceView(
                        results: viewModel.recentResults,
                        streak: viewModel.currentStreak
                    )
                    .staggeredAppearance(index: 2, totalCount: 4)
                }
                
                // Recent Results
                GameDetailRecentResults(
                    game: game,
                    results: viewModel.recentResults,
                    currentStreak: viewModel.currentStreak
                )
                .staggeredAppearance(index: 3, totalCount: 4)
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.vertical, Spacing.xl)
        }
        .scrollBounceBehavior(.automatic)
        .refreshable {
            await refreshData()
        }
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.large)
        // SIMPLE: Just use automatic transition
        .navigationTransition(.automatic)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .task {
            viewModel.setup(with: appState)
            
            // Check if we're navigating from notification
            if appState.isNavigatingFromNotification {
                isNavigatingFromNotification = true
                
                // Hide loading overlay after data loads
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await MainActor.run {
                        isNavigatingFromNotification = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(preSelectedGame: game)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareContent])
        }
        .overlay {
            // Loading overlay for notification navigation
            if isNavigatingFromNotification {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("Loading...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
            }
        }
    }
    
    private var shareButton: some View {
        Button {
            showingShareSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }
}
