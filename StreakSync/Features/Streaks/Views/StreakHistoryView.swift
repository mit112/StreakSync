//
//  StreakHistoryView.swift
//  StreakSync
//
//  Streak history — iOS 26 only.
//

import SwiftUI
import Charts

// MARK: - Streak History View
struct StreakHistoryView: View {
    let streak: GameStreak
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var hoveredDate: Date?
    @State private var showingStats = false

    private var game: Game? { appState.games.first { $0.id == streak.gameId } }
    private var gameColor: Color { game?.backgroundColor.color ?? .gray }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsHeader
                monthNavigation
                calendarSection
                if !monthResults.isEmpty { monthStatsSection }
            }
            .padding()
        }
        .scrollBounceBehavior(.automatic)
        .background {
            LinearGradient(colors: [gameColor.opacity(0.05), Color.clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
        .navigationTitle(game?.displayName ?? streak.gameName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 16) {
            HistoryStatBox(value: "\(streak.currentStreak)", label: "Current",
                           color: streak.isActive ? .green : .orange, icon: "flame.fill")
            HistoryStatBox(value: "\(streak.maxStreak)", label: "Best",
                           color: gameColor, icon: "trophy.fill")
            HistoryStatBox(value: streak.completionPercentage, label: "Success",
                           color: .blue, icon: "checkmark.seal.fill")
        }
        .scrollTransition { content, phase in
            content.opacity(phase.isIdentity ? 1 : 0.8).scaleEffect(phase.isIdentity ? 1 : 0.95)
        }
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation(.smooth) {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2).foregroundStyle(gameColor)
                    .symbolEffect(.bounce, value: selectedMonth)
            }
            .hoverEffect(.lift)

            Spacer()

            VStack(spacing: 4) {
                Text(selectedMonth.formatted(.dateTime.month(.wide)))
                    .font(.title3.weight(.semibold))
                Text(selectedMonth.formatted(.dateTime.year()))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .contentTransition(.numericText())

            Spacer()

            Button {
                withAnimation(.smooth) {
                    if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth),
                       nextMonth <= Date() {
                        selectedMonth = nextMonth
                    }
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2).foregroundStyle(gameColor)
                    .symbolEffect(.bounce, value: selectedMonth)
            }
            .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            .hoverEffect(.lift)
        }
        .scrollTransition { content, phase in
            content.blur(radius: phase.isIdentity ? 0 : 2)
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Weekday headers
            HStack(spacing: 8) {
                ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, day in
                    Text(day).font(.caption.weight(.medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(Array(calendarDays().enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        HistoryCalendarDayView(
                            date: date, result: result(for: date), groupedResult: groupedResult(for: date),
                            gameColor: gameColor, isSelected: selectedDate == date, isHovered: hoveredDate == date
                        ) {
                            withAnimation(.smooth(duration: 0.2)) {
                                selectedDate = selectedDate == date ? nil : date
                            }
                            HapticManager.shared.trigger(.buttonTap)
                        }
                        .onHover { isHovering in
                            withAnimation(.smooth(duration: 0.15)) {
                                hoveredDate = isHovering ? date : nil
                            }
                        }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }

            // Selected date detail
            if let selected = selectedDate {
                if let grouped = groupedResult(for: selected) {
                    iOS26SelectedDateGroupedDetail(date: selected, groupedResult: grouped, gameColor: gameColor)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .push(from: .top).combined(with: .opacity)))
                } else if let result = result(for: selected) {
                    iOS26SelectedDateDetail(date: selected, result: result, gameColor: gameColor)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .push(from: .top).combined(with: .opacity)))
                }
            }
        }
        .padding(20)
        .cardStyle(cornerRadius: 20)
        .scrollTransition { content, phase in
            content.opacity(phase.isIdentity ? 1 : 0.9)
        }
    }

    // MARK: - Month Stats Section

    private var monthStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Month Summary").font(.headline)

            HStack {
                Label("\(totalGamesPlayed) games played", systemImage: "gamecontroller.fill").font(.subheadline)
                Spacer()
                Label("\(totalGamesCompleted) completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).foregroundStyle(.green)
            }

            if game?.name.lowercased() == "pips" {
                pipsTimeBreakdown
            }

            if showingStats {
                chartsSection
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground))
        }
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.98)
        }
    }

    private var pipsTimeBreakdown: some View {
        VStack(spacing: 8) {
            ForEach(["Easy", "Medium", "Hard"], id: \.self) { difficulty in
                if let best = bestTime(for: difficulty), let avg = averageTime(for: difficulty) {
                    HStack {
                        Label("\(difficulty) Best: \(best)", systemImage: "clock.fill")
                            .font(.caption).foregroundStyle(difficultyColor(for: difficulty))
                        Spacer()
                        Label("Avg: \(avg)", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption).foregroundStyle(difficultyColor(for: difficulty))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        if game?.name.lowercased() == "pips" {
            iOS26TimeBasedChart(groupedResults: monthGroupedResults, gameColor: gameColor)
                .frame(height: 200)
                .transition(.asymmetric(insertion: .push(from: .trailing).combined(with: .opacity),
                                        removal: .push(from: .leading).combined(with: .opacity)))
        } else {
            iOS26PerformanceChart(results: monthResults, gameColor: gameColor)
                .frame(height: 200)
                .transition(.asymmetric(insertion: .push(from: .trailing).combined(with: .opacity),
                                        removal: .push(from: .leading).combined(with: .opacity)))
        }
    }

    private func difficultyColor(for difficulty: String) -> Color {
        switch difficulty {
        case "Easy": return .green
        case "Medium": return .yellow
        case "Hard": return .orange
        default: return .gray
        }
    }

    // MARK: - Data

    private var monthResults: [GameResult] {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return appState.recentResults
            .filter { $0.gameId == streak.gameId }
            .filter { month.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    private var monthGroupedResults: [GroupedGameResult] {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        guard let game = game else { return [] }
        return appState.getGroupedResults(for: game)
            .filter { month.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    private var totalGamesPlayed: Int {
        game?.name.lowercased() == "pips" ? monthGroupedResults.count : monthResults.count
    }

    private var totalGamesCompleted: Int {
        game?.name.lowercased() == "pips"
            ? monthGroupedResults.filter { $0.completionStatus.contains("Completed") }.count
            : monthResults.filter(\.completed).count
    }

    private func bestTime(for difficulty: String) -> String? {
        guard game?.name.lowercased() == "pips" else { return nil }
        let times = monthGroupedResults.flatMap { $0.results }
            .filter { $0.parsedData["difficulty"]?.lowercased() == difficulty.lowercased() }
            .filter(\.completed)
            .compactMap { $0.parsedData["time"] }
            .compactMap { parseTime($0) }
        guard let best = times.min() else { return nil }
        return formatTime(best)
    }

    private func averageTime(for difficulty: String) -> String? {
        guard game?.name.lowercased() == "pips" else { return nil }
        let times = monthGroupedResults.flatMap { $0.results }
            .filter { $0.parsedData["difficulty"]?.lowercased() == difficulty.lowercased() }
            .filter(\.completed)
            .compactMap { $0.parsedData["time"] }
            .compactMap { parseTime($0) }
        guard !times.isEmpty else { return nil }
        return formatTime(times.reduce(0, +) / times.count)
    }

    private func parseTime(_ s: String) -> Int? {
        let c = s.split(separator: ":")
        guard c.count == 2, let m = Int(c[0]), let s = Int(c[1]) else { return nil }
        return m * 60 + s
    }

    private func formatTime(_ t: Int) -> String { String(format: "%d:%02d", t / 60, t % 60) }

    private func calendarDays() -> [Date?] {
        let cal = Calendar.current
        guard let month = cal.dateInterval(of: .month, for: selectedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: month.start) - 1
        let numDays = cal.range(of: .day, in: .month, for: selectedMonth)?.count ?? 0
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for d in 1...numDays {
            if let date = cal.date(byAdding: .day, value: d - 1, to: month.start) { days.append(date) }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func result(for date: Date) -> GameResult? {
        monthResults.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func groupedResult(for date: Date) -> GroupedGameResult? {
        monthGroupedResults.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
