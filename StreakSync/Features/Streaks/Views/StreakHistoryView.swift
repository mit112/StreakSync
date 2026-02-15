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
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
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
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1)
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
            return grouped.completionStatus.contains("Completed") ? gameColor.opacity(0.15) : Color(.systemGray6)
        } else if let result = result {
            return result.completed ? gameColor.opacity(0.15) : Color.red.opacity(0.1)
        }
        return Color(.systemGray6)
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
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial) }
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
                .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial) }
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
        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 0.5))
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
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial) }
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
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.day()).font(.caption2) } }
            .chartYAxis { AxisMarks(position: .trailing) { _ in AxisGridLine(); AxisValueLabel().font(.caption2) } }
            .chartYScale(domain: 0...1)
        }
        .padding()
        .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial) }
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
