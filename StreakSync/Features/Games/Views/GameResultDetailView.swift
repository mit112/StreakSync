//
//  GameResultDetailView.swift
//  StreakSync
//
//  Single implementation — iOS 26 only.
//

import SwiftUI
import UIKit

// MARK: - Game Result Detail View
struct GameResultDetailView: View {
    let result: GameResult
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false

    @State private var scoreRevealed = false
    @State private var showShareSheet = false
    @State private var copiedToClipboard = false
    @State private var selectedShareFormat: ShareFormat = .full
    @State private var detailsOpacity: Double = 0

    private var game: Game? {
        appState.games.first { $0.id == result.gameId }
    }

    private var gameColor: Color {
        game?.backgroundColor.color ?? .gray
    }

    enum ShareFormat: String, CaseIterable {
        case full = "Full Result"
        case compact = "Compact"
        case stats = "With Stats"

        var icon: String {
            switch self {
            case .full: return "doc.text"
            case .compact: return "text.alignleft"
            case .stats: return "chart.bar"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            detailScrollView
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
        }
        .confirmationDialog("Delete this result?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Result", role: .destructive) { deleteResult() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the result and recalculate your streaks and achievements.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditGameResultView(result: result, game: game) {
                dismiss()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Scroll Content

    private var detailScrollView: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreHeroSection
                detailsGrid
                sharePreviewSection

                if result.gameName.lowercased() == "quordle" {
                    QuordleDetailBreakdown(result: result)
                        .opacity(detailsOpacity)
                }

                shareActionButton
            }
            .padding()
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.automatic)
        .scrollIndicators(.hidden)
        .background(Color(.systemBackground).ignoresSafeArea())
        .sensoryFeedback(.success, trigger: copiedToClipboard)
        .onAppear { startAnimationSequence() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [formatShareText()])
        }
    }

    // MARK: - Score Hero Section

    private var scoreHeroSection: some View {
        VStack(spacing: 16) {
            Text(result.scoreEmoji)
                .font(.system(size: 88))
                .scaleEffect(scoreRevealed ? 1 : 0.85)
                .opacity(scoreRevealed ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: scoreRevealed)

            Text(result.gameName.capitalized)
                .font(.title2.weight(.semibold))
                .opacity(scoreRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.1), value: scoreRevealed)

            HStack(spacing: 12) {
                ScoreBadge(score: result.displayScore, color: gameColor, revealed: scoreRevealed)
                completionLabel
            }
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var completionLabel: some View {
        if result.completed {
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
                .opacity(scoreRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.15), value: scoreRevealed)
        } else {
            Label("Not Completed", systemImage: "xmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .opacity(scoreRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.15), value: scoreRevealed)
        }
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        VStack(spacing: 16) {
            DetailRowCompact(
                icon: "calendar",
                label: "Date",
                value: result.date.formatted(date: .abbreviated, time: .omitted)
            )

            if let puzzleNumber = result.parsedData["puzzleNumber"] {
                DetailRowCompact(
                    icon: "number.square",
                    label: result.parsedData["mode"]?.lowercased() == "weekly" ? "Challenge" : "Puzzle",
                    value: "#\(puzzleNumber)"
                )
            }

            if result.gameName.lowercased() == Game.Names.quordle,
               result.parsedData["mode"]?.lowercased() == "weekly" {
                DetailRowCompact(icon: "calendar.badge.clock", label: "Mode", value: "Weekly Challenge")
            }

            if shouldShowAttempts {
                DetailRowCompact(
                    icon: attemptsIcon,
                    label: attemptsLabel,
                    value: result.displayScore
                )
            }

            if result.gameName.lowercased() == "linkedinzip",
               let backtrackCount = result.parsedData["backtrackCount"] {
                DetailRowCompact(icon: "arrow.uturn.backward", label: "Backtracks", value: backtrackCount)
            }

            if result.gameName.lowercased() != "linkedinzip",
               let time = result.parsedData["time"] {
                DetailRowCompact(icon: "clock", label: "Time", value: time)
            }
        }
        .opacity(detailsOpacity)
        .animation(.easeOut(duration: 0.25), value: detailsOpacity)
    }

    private var shouldShowAttempts: Bool {
        let name = result.gameName.lowercased()
        let excluded = ["linkedinzip", "linkedintango", "linkedinqueens", "linkedincrossclimb"]
        return !excluded.contains(name)
    }

    private var attemptsIcon: String {
        let name = result.gameName.lowercased()
        if name == "linkedinpinpoint" { return "target" }
        if name == "strands" { return "lightbulb" }
        return "target"
    }

    private var attemptsLabel: String {
        let name = result.gameName.lowercased()
        if name == "linkedinpinpoint" { return "Guesses" }
        if name == "strands" { return "Hints" }
        return "Attempts"
    }

    // MARK: - Share Preview

    private var sharePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share Options")
                .font(.headline)
                .foregroundStyle(.primary)

            Picker("Share Format", selection: $selectedShareFormat) {
                ForEach(ShareFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Text(formatShareText())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

            Button {
                copyToClipboard()
            } label: {
                Label(copiedToClipboard ? "Copied" : "Copy to Clipboard",
                      systemImage: copiedToClipboard ? "checkmark.circle" : "doc.on.doc")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(detailsOpacity)
        .animation(.easeOut(duration: 0.3), value: detailsOpacity)
    }

    // MARK: - Share Action Button

    private var shareActionButton: some View {
        Button {
            showShareSheet = true
            HapticManager.shared.trigger(.buttonTap)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(gameColor)
    }

    // MARK: - Helper Methods

    private func startAnimationSequence() {
        withAnimation(.easeOut(duration: 0.25)) {
            scoreRevealed = true
            detailsOpacity = 1
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = formatShareText()
        copiedToClipboard = true
        HapticManager.shared.trigger(.achievement)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }

    private func deleteResult() {
        HapticManager.shared.trigger(.error)
        if let onDelete = onDelete {
            onDelete()
        } else {
            appState.deleteGameResult(result)
        }
        dismiss()
    }

    private func formatShareText() -> String {
        switch selectedShareFormat {
        case .full:
            return result.sharedText
        case .compact:
            let puzzleInfo = result.parsedData["puzzleNumber"].map { " #\($0)" } ?? ""
            return "\(result.gameName)\(puzzleInfo) \(result.displayScore)"
        case .stats:
            let puzzleInfo = result.parsedData["puzzleNumber"].map { " #\($0)" } ?? ""
            let streak = appState.streaks.first { $0.gameId == result.gameId }
            let streakInfo = streak.map { "\nStreak: \($0.currentStreak) days 🔥" } ?? ""
            return """
            \(result.gameName)\(puzzleInfo)
            Score: \(result.displayScore)
            \(result.scoreEmoji)\(streakInfo)
            
            via @StreakSync
            """
        }
    }
}
