//
//  GameResultDetailView.swift
//  StreakSync
//
//  iOS 26 Enhanced game result detail with animations and materials
//

import SwiftUI
import UIKit

// MARK: - Game Result Detail View
struct GameResultDetailView: View {
    let result: GameResult
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var showingDeleteConfirmation = false
    
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
    
    private var safeIconName: String {
        guard let iconName = game?.iconSystemName, !iconName.isEmpty else {
            return "gamecontroller"
        }
        return iconName
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
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                if #available(iOS 26.0, *) {
                    iOS26DetailView
                } else {
                    legacyDetailView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .confirmationDialog("Delete this result?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Result", role: .destructive) {
                deleteResult()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the result and recalculate your streaks and achievements.")
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - iOS 26 Implementation
    @available(iOS 26.0, *)
    private var iOS26DetailView: some View {
        ScrollView {
            VStack(spacing: 24) {
                iOS26ScoreHeroSection
                iOS26DetailsGrid
                iOS26SharePreview
                iOS26ActionButtons
            }
            .padding()
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.automatic)
        .scrollIndicators(.hidden)
        .background(iOS26BackgroundGradient)
        .onAppear {
            startAnimationSequence()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [formatShareText()])
        }
        .sensoryFeedback(.success, trigger: copiedToClipboard)
    }
    
    // MARK: - iOS 26 Score Hero Section
    @available(iOS 26.0, *)
    private var iOS26ScoreHeroSection: some View {
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
                ScoreBadge(
                    score: result.displayScore,
                    color: gameColor,
                    revealed: scoreRevealed
                )
                
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
        }
        .padding(.top, 20)
    }
    
    // MARK: - iOS 26 Details Grid
    @available(iOS 26.0, *)
    private var iOS26DetailsGrid: some View {
        VStack(spacing: 16) {
            DetailRowCompact(
                icon: "calendar",
                label: "Date",
                value: result.date.formatted(date: .abbreviated, time: .omitted)
            )
            
            if let puzzleNumber = result.parsedData["puzzleNumber"] {
                DetailRowCompact(
                    icon: "number.square",
                    label: "Puzzle",
                    value: "#\(puzzleNumber)"
                )
            }
            
            if !(result.gameName.lowercased() == "linkedinzip" || result.gameName.lowercased() == "linkedintango" || result.gameName.lowercased() == "linkedinqueens" || result.gameName.lowercased() == "linkedincrossclimb") {
                DetailRowCompact(
                    icon: result.gameName.lowercased() == "linkedinpinpoint" ? "target" : (result.gameName.lowercased() == "strands" ? "lightbulb" : "target"),
                    label: result.gameName.lowercased() == "linkedinpinpoint" ? "Guesses" : (result.gameName.lowercased() == "strands" ? "Hints" : "Attempts"),
                    value: result.displayScore
                )
            }
            
            if result.gameName.lowercased() == "linkedinzip",
               let backtrackCount = result.parsedData["backtrackCount"] {
                DetailRowCompact(
                    icon: "arrow.uturn.backward",
                    label: "Backtracks",
                    value: backtrackCount
                )
            }
            
            if result.gameName.lowercased() != "linkedinzip",
               let time = result.parsedData["time"] {
                DetailRowCompact(
                    icon: "clock",
                    label: "Time",
                    value: time
                )
            }
        }
        .opacity(detailsOpacity)
        .animation(.easeOut(duration: 0.25), value: detailsOpacity)
    }
    
    // MARK: - iOS 26 Share Preview
    @available(iOS 26.0, *)
    private var iOS26SharePreview: some View {
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
                Label(copiedToClipboard ? "Copied" : "Copy to Clipboard", systemImage: copiedToClipboard ? "checkmark.circle" : "doc.on.doc")
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
    
    // MARK: - iOS 26 Action Buttons
    @available(iOS 26.0, *)
    private var iOS26ActionButtons: some View {
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
    
    // MARK: - iOS 26 Background
    @available(iOS 26.0, *)
    private var iOS26BackgroundGradient: some View {
        Color(.systemBackground).ignoresSafeArea()
    }
    
    // MARK: - Legacy Implementation
    private var legacyDetailView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score display
                VStack(spacing: 16) {
                    Text(result.scoreEmoji)
                        .font(.system(size: 72))
                        .scaleEffect(scoreRevealed ? 1 : 0.5)
                        .opacity(scoreRevealed ? 1 : 0)
                    
                    Text(result.gameName.capitalized)
                        .font(.title3.weight(.medium))
                    
                    Text(result.displayScore)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    DetailRowCompact(
                        icon: "calendar",
                        label: "Date",
                        value: result.date.formatted(date: .abbreviated, time: .omitted)
                    )
                    
                    DetailRowCompact(
                        icon: "info.circle",
                        label: "Status",
                        value: result.completed ? "Completed" : "Not Completed"
                    )
                    
                    if !(result.gameName.lowercased() == "linkedinzip" || result.gameName.lowercased() == "linkedintango" || result.gameName.lowercased() == "linkedinqueens" || result.gameName.lowercased() == "linkedincrossclimb" || result.gameName.lowercased() == "octordle") {
                        DetailRowCompact(
                            icon: result.gameName.lowercased() == "linkedinpinpoint" ? "target" : (result.gameName.lowercased() == "strands" ? "lightbulb" : "target"),
                            label: result.gameName.lowercased() == "linkedinpinpoint" ? "Guesses" : (result.gameName.lowercased() == "strands" ? "Hints" : "Attempts"),
                            value: result.displayScore
                        )
                    }
                    
                    if let puzzleNumber = result.parsedData["puzzleNumber"] {
                        DetailRowCompact(
                            icon: "number.square",
                            label: "Puzzle",
                            value: "#\(puzzleNumber)"
                        )
                    }
                    
                    if result.gameName.lowercased() == "linkedinzip",
                       let backtrackCount = result.parsedData["backtrackCount"] {
                        DetailRowCompact(
                            icon: "arrow.uturn.backward",
                            label: "Backtracks",
                            value: backtrackCount
                        )
                    }
                }
                
                // Quordle-specific breakdown
                if result.gameName.lowercased() == "quordle" {
                    QuordleDetailBreakdown(result: result)
                        .opacity(detailsOpacity)
                }
                
                // Share button
                ShareLink(item: formatShareText()) {
                    Label("Share Result", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            startAnimationSequence()
        }
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
        
        // Call the onDelete callback if provided (from parent view)
        if let onDelete = onDelete {
            onDelete()
        } else {
            // Fallback to direct AppState deletion
            appState.deleteGameResult(result)
        }
        
        // Dismiss the sheet
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

// MARK: - Supporting Views

// Score Badge Component
struct ScoreBadge: View {
    let score: String
    let color: Color
    let revealed: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Score:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(score)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: score)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(color.opacity(0.1))
                .overlay {
                    Capsule()
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                }
        }
        .scaleEffect(revealed ? 1 : 0.8)
        .opacity(revealed ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: revealed)
    }
}

// MARK: - Compact Detail Row
struct DetailRowCompact: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image.safeSystemName(icon, fallback: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// Detail Card Component
@available(iOS 26.0, *)
struct DetailCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image.safeSystemName(icon, fallback: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, value: isHovered)
                
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                }
                .shadow(
                    color: isHovered ? color.opacity(0.1) : .clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .hoverEffect(.highlight)
    }
}

// Legacy Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding()
    }
}

// MARK: - Quordle Detail Breakdown
struct QuordleDetailBreakdown: View {
    let result: GameResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("Puzzle Breakdown")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            // Individual puzzle scores
            VStack(spacing: 12) {
                if let score1 = result.parsedData["score1"],
                   let score2 = result.parsedData["score2"],
                   let score3 = result.parsedData["score3"],
                   let score4 = result.parsedData["score4"] {
                    
                    QuordlePuzzleRow(puzzleNumber: 1, score: score1, maxAttempts: result.maxAttempts)
                    QuordlePuzzleRow(puzzleNumber: 2, score: score2, maxAttempts: result.maxAttempts)
                    QuordlePuzzleRow(puzzleNumber: 3, score: score3, maxAttempts: result.maxAttempts)
                    QuordlePuzzleRow(puzzleNumber: 4, score: score4, maxAttempts: result.maxAttempts)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Summary stats
            VStack(spacing: 8) {
                if let completedStr = result.parsedData["completedPuzzles"],
                   let completed = Int(completedStr) {
                    
                    HStack {
                        Text("Success Rate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(completed)/4 puzzles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(completed == 4 ? .green : (completed > 0 ? .orange : .red))
                    }
                    
                    // Average score (only if some completed)
                    if completed > 0, let avgScore = calculateAverageScore() {
                        HStack {
                            Text("Average Attempts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f/\(result.maxAttempts)", avgScore))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func calculateAverageScore() -> Double? {
        guard let score1 = result.parsedData["score1"],
              let score2 = result.parsedData["score2"],
              let score3 = result.parsedData["score3"],
              let score4 = result.parsedData["score4"] else {
            return nil
        }
        
        let scores = [score1, score2, score3, score4]
        let validScores = scores.compactMap { score -> Int? in
            guard score != "failed" else { return nil }
            return Int(score)
        }
        
        guard !validScores.isEmpty else { return nil }
        
        let sum = validScores.reduce(0, +)
        return Double(sum) / Double(validScores.count)
    }
}

// MARK: - Quordle Puzzle Row
struct QuordlePuzzleRow: View {
    let puzzleNumber: Int
    let score: String
    let maxAttempts: Int
    
    private var isCompleted: Bool {
        score != "failed"
    }
    
    private var displayScore: String {
        isCompleted ? "\(score)/\(maxAttempts)" : "Failed"
    }
    
    private var emoji: String {
        guard isCompleted, let scoreInt = Int(score) else {
            return "❌"
        }
        
        switch scoreInt {
        case 1...3: return "🟢"
        case 4...6: return "🟡"
        case 7...8: return "🟠"
        case 9: return "🔴"
        default: return "⚪️"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Puzzle indicator
            Text(emoji)
                .font(.title3)
            
            // Puzzle label
            Text("Puzzle \(puzzleNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Score
            Text(displayScore)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCompleted ? .green : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isCompleted ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                )
        }
        .padding(.vertical, 4)
    }
}

// Share Sheet for iOS
//struct ShareSheet: UIViewControllerRepresentable {
//    let items: [Any]
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        let controller = UIActivityViewController(
//            activityItems: items,
//            applicationActivities: nil
//        )
//        return controller
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}

// MARK: - Preview
#Preview("Game Result Detail") {
    GameResultDetailView(
        result: GameResult(
//            id: UUID(),
            gameId: UUID(),
            gameName: "Wordle",
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1,234 3/6\n\n⬛🟨⬛🟨⬛\n🟨⬛🟨⬛⬛\n🟩🟩🟩🟩🟩",
            parsedData: ["puzzleNumber": "1,234", "time": "2:34"]
        )
    )
    .environment(AppState())
}
