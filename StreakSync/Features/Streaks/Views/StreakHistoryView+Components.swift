//
//  StreakHistoryView+Components.swift
//  StreakSync
//
//  Supporting view components for StreakHistoryView.
//

import Charts
import SwiftUI

// MARK: - History Stat Box

struct HistoryStatBox: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            Image.safeSystemName(icon, fallback: "chart.bar")
                .font(.title2).foregroundStyle(color)
                .symbolEffect(.bounce, value: isHovered)

            Text(value).font(.title2.weight(.bold)).foregroundStyle(color)
                .contentTransition(.numericText())

            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.5)
                }
                .shadow(color: isHovered ? color.opacity(0.15) : .black.opacity(0.1),
                        radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .hoverEffect(.lift)
    }
}

// MARK: - History Calendar Day View

struct HistoryCalendarDayView: View {
    let date: Date
    let result: GameResult?
    let groupedResult: GroupedGameResult?
    let gameColor: Color
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
                    .overlay {
                        if isToday {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.blue, lineWidth: 2)
                        } else if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(gameColor, lineWidth: 2)
                        }
                    }

                VStack(spacing: 2) {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(.body, design: .rounded).weight(isToday ? .bold : .regular))
                        .foregroundStyle(textColor)

                    if let grouped = groupedResult {
                        HStack(spacing: 2) {
                            if grouped.hasEasy { Circle().fill(.green).frame(width: 5, height: 5) }
                            if grouped.hasMedium { Circle().fill(.yellow).frame(width: 5, height: 5) }
                            if grouped.hasHard { Circle().fill(.orange).frame(width: 5, height: 5) }
                        }
                    } else if let result = result {
                        Circle()
                            .fill(result.completed ? Color.green : Color.red.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : (isSelected ? 1.05 : 1.0))
        .shadow(color: isHovered ? gameColor.opacity(0.2) : .clear, radius: isHovered ? 4 : 0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .animation(.smooth(duration: 0.2), value: isSelected)
    }

    private var backgroundColor: Color {
        if let grouped = groupedResult {
            return grouped.completionStatus.contains("Completed") ? gameColor.opacity(0.15) : Color(.tertiarySystemFill)
        } else if let result = result {
            return result.completed ? gameColor.opacity(0.15) : Color.red.opacity(0.1)
        }
        return Color(.tertiarySystemFill)
    }

    private var textColor: Color {
        if isToday { return .blue }
        if groupedResult != nil || result != nil { return .primary }
        return .secondary
    }
}

// MARK: - iOS 26 Selected Date Detail

struct iOS26SelectedDateDetail: View {
    let date: Date
    let result: GameResult
    let gameColor: Color

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    Label(result.completed ? "Completed" : "Failed",
                          systemImage: result.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption).foregroundStyle(result.completed ? .green : .red)
                    if let score = result.score {
                        Text("Score: \(score)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(result.displayScore).font(.title3.weight(.bold)).foregroundStyle(gameColor)
        }
        .padding()
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)) }
    }
}

// MARK: - iOS 26 Selected Date Grouped Detail

struct iOS26SelectedDateGroupedDetail: View {
    let date: Date
    let groupedResult: GroupedGameResult
    let gameColor: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 8) {
                            Label(groupedResult.completionStatus, systemImage: completionIcon)
                                .font(.caption).foregroundStyle(completionColor)
                            if let bestTime = groupedResult.bestTime {
                                Text("• \(bestTime)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        if groupedResult.hasEasy { Circle().fill(.green).frame(width: 8, height: 8) }
                        if groupedResult.hasMedium { Circle().fill(.yellow).frame(width: 8, height: 8) }
                        if groupedResult.hasHard { Circle().fill(.orange).frame(width: 8, height: 8) }
                    }
                    Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(groupedResult.results.enumerated()), id: \.element.id) { _, result in
                        DifficultyResultRowView(result: result)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)) }
    }

    private var completionIcon: String {
        switch groupedResult.results.filter(\.completed).count {
        case 3: return "trophy.fill"
        case 2: return "medal.fill"
        case 1: return "rosette"
        default: return "circle"
        }
    }

    private var completionColor: Color {
        switch groupedResult.results.filter(\.completed).count {
        case 3: return .yellow
        case 2: return .gray
        case 1: return .brown
        default: return .secondary
        }
    }
}

// MARK: - Difficulty Result Row

struct DifficultyResultRowView: View {
    let result: GameResult

    var body: some View {
        HStack {
            Circle().fill(difficultyColor).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(difficultyText).font(.subheadline).foregroundStyle(.primary)
                Text(result.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var difficultyColor: Color {
        guard let d = result.parsedData["difficulty"] else { return .gray }
        switch d.lowercased() {
        case "easy": return .green
        case "medium": return .yellow
        case "hard": return .orange
        default: return .gray
        }
    }

    private var difficultyText: String {
        guard let d = result.parsedData["difficulty"], let t = result.parsedData["time"] else { return "" }
        return "\(d) - \(t)"
    }
}

// MARK: - iOS 26 Performance Chart

struct iOS26PerformanceChart: View {
    let results: [GameResult]
    let gameColor: Color

    var body: some View {
        Chart(results) { result in
            if let score = result.score {
                LineMark(x: .value("Date", result.date), y: .value("Score", score))
                    .foregroundStyle(gameColor).interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", result.date), y: .value("Score", score))
                    .foregroundStyle(result.completed ? Color.green : Color.red).symbolSize(100)
            }
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.day()) } }
        .chartYAxis { AxisMarks { _ in AxisGridLine(); AxisValueLabel() } }
        .padding()
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)) }
    }
}

// MARK: - iOS 26 Time Based Chart

struct iOS26TimeBasedChart: View {
    let groupedResults: [GroupedGameResult]
    let gameColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Times").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach(["Easy", "Medium", "Hard"], id: \.self) { diff in
                            if let best = bestTime(for: diff) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(diff).font(.caption2).foregroundStyle(diffColor(diff))
                                    Text(best).font(.caption.weight(.medium))
                                }
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Completion").font(.caption).foregroundStyle(.secondary)
                    Text("\(totalCompleted)/\(totalPossible)")
                        .font(.caption.weight(.medium)).foregroundStyle(gameColor)
                }
            }

            Chart(groupedResults.prefix(7)) { gr in
                let rate = Double(gr.results.filter(\.completed).count) / Double(gr.results.count)
                BarMark(x: .value("Date", gr.date), y: .value("Completion", rate))
                    .foregroundStyle(gameColor.gradient).cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.day()).font(.caption2) }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in AxisGridLine(); AxisValueLabel().font(.caption2) }
            }
            .chartYScale(domain: 0...1)
        }
        .padding()
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)) }
    }

    private func bestTime(for diff: String) -> String? {
        let times = groupedResults.flatMap { $0.results }
            .filter { $0.parsedData["difficulty"]?.lowercased() == diff.lowercased() }
            .filter(\.completed)
            .compactMap { $0.parsedData["time"] }
            .compactMap { parseT($0) }
        guard let best = times.min() else { return nil }
        return String(format: "%d:%02d", best / 60, best % 60)
    }

    private func parseT(_ s: String) -> Int? {
        let c = s.split(separator: ":"); guard c.count == 2, let m = Int(c[0]), let s = Int(c[1]) else { return nil }
        return m * 60 + s
    }

    private func diffColor(_ d: String) -> Color {
        switch d { case "Easy": return .green; case "Medium": return .yellow; case "Hard": return .orange; default: return .gray }
    }

    private var totalCompleted: Int { groupedResults.flatMap { $0.results }.filter(\.completed).count }
    private var totalPossible: Int { groupedResults.flatMap { $0.results }.count }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StreakHistoryView(
            streak: GameStreak(
                gameId: Game.wordle.id, gameName: "wordle",
                currentStreak: 15, maxStreak: 23,
                totalGamesPlayed: 100, totalGamesCompleted: 85,
                lastPlayedDate: Date(),
                streakStartDate: Date().addingTimeInterval(-15 * 24 * 60 * 60)
            )
        )
        .environment(AppState())
    }
}
