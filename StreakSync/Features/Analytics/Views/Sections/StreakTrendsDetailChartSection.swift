//
//  StreakTrendsDetailChartSection.swift
//  StreakSync
//
//  Interactive chart with selection, point detail card, and game breakdown chips.
//

import SwiftUI
import Charts

struct StreakTrendsDetailChartSection: View {
    let trends: [StreakTrendPoint]
    let rangeResults: [GameResult]
    let rangeGames: [Game]
    let isLoading: Bool
    let timeRange: AnalyticsTimeRange
    let gameDisplayName: String
    @Binding var selectedDate: Date?

    private var selectedPoint: StreakTrendPoint? {
        guard let date = selectedDate else { return nil }
        return trends.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("\(gameDisplayName) • \(timeRange.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else if trends.isEmpty {
                emptyChartView
            } else {
                VStack(spacing: 12) {
                    Chart {
                        ForEach(trends, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Active Streaks", point.totalActiveStreaks)
                            )
                            .foregroundStyle(.blue.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Active Streaks", point.totalActiveStreaks)
                            )
                            .foregroundStyle(.blue.opacity(0.2).gradient)
                            .interpolationMethod(.catmullRom)

                            if let selected = selectedPoint, selected.date == point.date {
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Active Streaks", point.totalActiveStreaks)
                                )
                                .foregroundStyle(.blue)
                                .symbol(.circle)
                                .symbolSize(100)
                            }
                        }
                    }
                    .frame(height: 300)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXSelection(value: $selectedDate)

                    if let point = selectedPoint {
                        selectedPointCard(point)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        tapToInspectHint
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Selected Point Card

    private func selectedPointCard(_ point: StreakTrendPoint) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.date, format: .dateTime.month().day().year())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(point.date, format: .dateTime.weekday(.wide))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                streakStatusBadge(for: point)
            }

            HStack(spacing: 12) {
                statPill(value: "\(point.totalActiveStreaks)", label: "Active", color: .blue)
                statPill(value: "\(point.gamesCompleted)", label: "Completed", color: .green)
                statPill(value: successRate(for: point), label: "Success Rate", color: .purple)
            }

            if point.gamesPlayed > 0 {
                gameBreakdownChips(for: point)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(color.opacity(0.1))
        }
    }

    // MARK: - Helpers

    private func successRate(for point: StreakTrendPoint) -> String {
        guard point.gamesPlayed > 0 else { return "0%" }
        let rate = (Double(point.gamesCompleted) / Double(point.gamesPlayed)) * 100
        return String(format: "%.0f%%", rate)
    }

    private func streakStatusBadge(for point: StreakTrendPoint) -> some View {
        let (icon, text, color) = getStreakStatus(for: point)
        return HStack(spacing: 4) {
            Image.safeSystemName(icon, fallback: "questionmark.circle")
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
        }
    }

    private func getStreakStatus(for point: StreakTrendPoint) -> (icon: String, text: String, color: Color) {
        let calendar = Calendar.current
        let pointIndex = trends.firstIndex { calendar.isDate($0.date, inSameDayAs: point.date) } ?? 0

        if pointIndex > 0 {
            let previousPoint = trends[pointIndex - 1]
            if point.gamesPlayed > 0 {
                if previousPoint.totalActiveStreaks == 0 && point.totalActiveStreaks > 0 {
                    return ("sparkles", "Started", .green)
                } else if point.totalActiveStreaks > previousPoint.totalActiveStreaks {
                    return ("arrow.up.circle.fill", "Grew", .green)
                } else if point.totalActiveStreaks == previousPoint.totalActiveStreaks && point.gamesPlayed > 0 {
                    return ("checkmark.circle.fill", "Maintained", .blue)
                } else if point.totalActiveStreaks < previousPoint.totalActiveStreaks {
                    return ("exclamationmark.triangle.fill", "Lost", .orange)
                }
            } else if previousPoint.totalActiveStreaks > 0 && point.totalActiveStreaks > 0 {
                return ("pause.circle.fill", "Safe Skip", .yellow)
            } else if previousPoint.totalActiveStreaks > 0 && point.totalActiveStreaks == 0 {
                return ("xmark.circle.fill", "Broken", .red)
            }
        } else if point.gamesPlayed > 0 {
            return ("sparkles", "Started", .green)
        }
        return ("minus.circle.fill", "No Activity", .secondary)
    }

    private func gameBreakdownChips(for point: StreakTrendPoint) -> some View {
        let calendar = Calendar.current
        let dayResults = rangeResults.filter { calendar.isDate($0.date, inSameDayAs: point.date) }
        let uniqueGames = Dictionary(grouping: dayResults, by: { $0.gameId })

        return VStack(alignment: .leading, spacing: 8) {
            Text("Games Played")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(uniqueGames.keys), id: \.self) { gameId in
                        if let game = rangeGames.first(where: { $0.id == gameId }) {
                            let gameResults = uniqueGames[gameId] ?? []
                            let completed = gameResults.filter(\.completed).count
                            let total = gameResults.count
                            gameChip(game: game, completed: completed, total: total)
                        }
                    }
                }
            }
        }
    }

    private func gameChip(game: Game, completed: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                .font(.caption)
                .foregroundStyle(game.backgroundColor.color)
            Text(game.displayName)
                .font(.caption)
                .fontWeight(.medium)
            if completed == total {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text("\(completed)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color(.tertiarySystemFill))
                .overlay(
                    Capsule()
                        .stroke(game.backgroundColor.color.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var tapToInspectHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("Tap chart to see daily details")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemFill))
        }
    }

    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No Activity Data")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start playing games to see your trends")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
}
