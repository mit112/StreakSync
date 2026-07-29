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
            // The generic score emoji carried no product identity; the seal does, and it
            // states the score and completion status explicitly (DESIGN_AUDIT §4.7).
            // `scoreEmoji` itself is unchanged because generated share text still uses it.
            GameResultSeal(result: result, game: game, revealed: scoreRevealed)

            // `result.gameName` is stored lowercase, so keep the pre-seal capitalization
            // for the fallback path where the catalog has no matching game.
            Text(game?.displayName ?? result.gameName.capitalized)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(scoreRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.1), value: scoreRevealed)
        }
        .padding(.top, 20)
    }

    // MARK: - Details Grid

    /// Ordinary facts are open rows separated by dividers. One rounded card per row made
    /// Date, Puzzle, Attempts, and Time look as important as the seal (DESIGN_AUDIT §4.7).
    private var detailsGrid: some View {
        VStack(spacing: 0) {
            detailRow(
                icon: "calendar",
                label: "Date",
                value: result.date.formatted(date: .abbreviated, time: .omitted)
            )

            if let puzzleNumber = result.parsedData["puzzleNumber"] {
                Divider()
                detailRow(
                    icon: "number.square",
                    label: result.parsedData["mode"]?.lowercased() == "weekly" ? "Challenge" : "Puzzle",
                    value: "#\(puzzleNumber)"
                )
            }

            if result.gameName.lowercased() == Game.Names.quordle,
               result.parsedData["mode"]?.lowercased() == "weekly" {
                Divider()
                detailRow(icon: "calendar.badge.clock", label: "Mode", value: "Weekly Challenge")
            }

            if shouldShowAttempts {
                Divider()
                detailRow(
                    icon: attemptsIcon,
                    label: attemptsLabel,
                    value: result.displayScore
                )
            }

            if result.gameName.lowercased() == "linkedinzip",
               let backtrackCount = result.parsedData["backtrackCount"] {
                Divider()
                detailRow(icon: "arrow.uturn.backward", label: "Backtracks", value: backtrackCount)
            }

            if result.gameName.lowercased() != "linkedinzip",
               let time = result.parsedData["time"] {
                Divider()
                detailRow(icon: "clock", label: "Time", value: time)
            }
        }
        .opacity(detailsOpacity)
        .animation(.easeOut(duration: 0.25), value: detailsOpacity)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.trailing)
        } label: {
            Label {
                Text(label)
            } icon: {
                Image.safeSystemName(icon, fallback: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.md)
    }

    private var shouldShowAttempts: Bool {
        let name = result.gameName.lowercased()
        let excluded = ["linkedinzip", "linkedintango", "linkedinqueens", "linkedincrossclimb", "linkedinminisudoku"]
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

            // Copy is the primary action inside Share Options, so it looks enabled and
            // states its own result instead of relying on a faint style change (§4.7).
            Button(action: copyToClipboard) {
                Label(copiedToClipboard ? "Copied" : "Copy to Clipboard",
                      systemImage: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(StreakSyncBrand.primary)
            // Deliberately NOT .disabled() while confirming: a disabled prominent button
            // drops its tint and dims its label to 1.44:1 in light and 2.53:1 in dark +
            // Increased Contrast, so the confirmation was the least legible thing on the
            // screen. Re-tapping simply copies again.
            .accessibilityLabel(copiedToClipboard ? "Copied to clipboard" : "Copy result to clipboard")
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

    /// Secondary to Copy, so the hierarchy between the two share actions is unambiguous.
    private var shareActionButton: some View {
        Button {
            showShareSheet = true
            HapticManager.shared.trigger(.buttonTap)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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
        AccessibilityAnnouncer.announce("Result copied to clipboard")
        Task {
            try? await Task.sleep(for: .seconds(2))
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
