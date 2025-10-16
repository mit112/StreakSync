//
//  StreakHistoryView.swift
//  StreakSync
//
//  Enhanced streak history with iOS 26 calendar transitions and interactions
//

import SwiftUI
import Charts

// MARK: - Streak History View
struct StreakHistoryView: View {
    let streak: GameStreak
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var hoveredDate: Date?
    @State private var showingStats = false
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    private var gameColor: Color {
        game?.backgroundColor.color ?? .gray
    }
    
    // MARK: - Month Results
    private var monthResults: [GameResult] {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        
        return appState.recentResults
            .filter { $0.gameId == streak.gameId }
            .filter { month.contains($0.date) }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Month Grouped Results (for games like Pips)
    private var monthGroupedResults: [GroupedGameResult] {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        guard let game = game else { return [] }
        
        let allGroupedResults = appState.getGroupedResults(for: game)
        let filteredByMonth = allGroupedResults.filter { month.contains($0.date) }
        let sortedResults = filteredByMonth.sorted { $0.date < $1.date }
        
        return sortedResults
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26HistoryView
        } else {
            legacyHistoryView
        }
    }
    
    // MARK: - iOS 26 Implementation
    @available(iOS 26.0, *)
    private var iOS26HistoryView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Enhanced stats header
                iOS26StatsHeader
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.8)
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                    }
                
                // Month navigation
                iOS26MonthNavigation
                    .scrollTransition { content, phase in
                        content
                            .blur(radius: phase.isIdentity ? 0 : 2)
                    }
                
                // Calendar grid
                iOS26CalendarGrid
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.9)
                    }
                
                // Month statistics
                if !monthResults.isEmpty {
                    iOS26MonthStats
                        .scrollTransition { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.98)
                        }
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.automatic)
        .background {
            LinearGradient(
                colors: [
                    gameColor.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .navigationTitle(game?.displayName ?? streak.gameName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - iOS 26 Stats Header
    @available(iOS 26.0, *)
    private var iOS26StatsHeader: some View {
        HStack(spacing: 16) {
            iOS26StatBox(
                value: "\(streak.currentStreak)",
                label: "Current",
                color: streak.isActive ? .green : .orange,
                icon: "flame.fill"
            )
            
            iOS26StatBox(
                value: "\(streak.maxStreak)",
                label: "Best",
                color: gameColor,
                icon: "trophy.fill"
            )
            
            iOS26StatBox(
                value: streak.completionPercentage,
                label: "Success",
                color: .blue,
                icon: "checkmark.seal.fill"
            )
        }
    }
    
    // MARK: - iOS 26 Month Navigation
    @available(iOS 26.0, *)
    private var iOS26MonthNavigation: some View {
        HStack {
            Button {
                withAnimation(.smooth) {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(gameColor)
                    .symbolEffect(.bounce, value: selectedMonth)
            }
            .hoverEffect(.lift)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(selectedMonth.formatted(.dateTime.month(.wide)))
                    .font(.title3.weight(.semibold))
                Text(selectedMonth.formatted(.dateTime.year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .font(.title2)
                    .foregroundStyle(gameColor)
                    .symbolEffect(.bounce, value: selectedMonth)
            }
            .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            .hoverEffect(.lift)
        }
    }
    
    // MARK: - iOS 26 Calendar Grid
    @available(iOS 26.0, *)
    private var iOS26CalendarGrid: some View {
        VStack(spacing: 12) {
            weekdayHeadersView
            calendarDaysGrid
            selectedDateDetailView
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }
    
    @available(iOS 26.0, *)
    private var weekdayHeadersView: some View {
        HStack(spacing: 8) {
            ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    @available(iOS 26.0, *)
    private var calendarDaysGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
            spacing: 8
        ) {
            ForEach(Array(calendarDays().enumerated()), id: \.offset) { index, date in
                if let date = date {
                    calendarDayView(for: date)
                } else {
                    Color.clear
                        .frame(height: 48)
                }
            }
        }
    }
    
    @available(iOS 26.0, *)
    private func calendarDayView(for date: Date) -> some View {
        iOS26CalendarDayView(
            date: date,
            result: result(for: date),
            gameColor: gameColor,
            isSelected: selectedDate == date,
            isHovered: hoveredDate == date
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
    }
    
    @available(iOS 26.0, *)
    private var selectedDateDetailView: some View {
        Group {
            if let selected = selectedDate {
                if let groupedResult = groupedResult(for: selected) {
                    groupedDateDetailView(selected: selected, groupedResult: groupedResult)
                } else if let result = result(for: selected) {
                    individualDateDetailView(selected: selected, result: result)
                }
            }
        }
    }
    
    @available(iOS 26.0, *)
    private func groupedDateDetailView(selected: Date, groupedResult: GroupedGameResult) -> some View {
        iOS26SelectedDateGroupedDetail(
            date: selected,
            groupedResult: groupedResult,
            gameColor: gameColor
        )
        .transition(.asymmetric(
            insertion: .push(from: .bottom).combined(with: .opacity),
            removal: .push(from: .top).combined(with: .opacity)
        ))
    }
    
    @available(iOS 26.0, *)
    private func individualDateDetailView(selected: Date, result: GameResult) -> some View {
        iOS26SelectedDateDetail(
            date: selected,
            result: result,
            gameColor: gameColor
        )
        .transition(.asymmetric(
            insertion: .push(from: .bottom).combined(with: .opacity),
            removal: .push(from: .top).combined(with: .opacity)
        ))
    }
    
    // MARK: - iOS 26 Month Stats
    @available(iOS 26.0, *)
    private var iOS26MonthStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Month Summary")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Label("\(totalGamesPlayed) games played", systemImage: "gamecontroller.fill")
                    .font(.subheadline)
                
                Spacer()
                
                Label("\(totalGamesCompleted) completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            
            // Time-based metrics for Pips - separate by difficulty
            if game?.name.lowercased() == "pips" {
                VStack(spacing: 8) {
                    // Easy difficulty
                    if let bestEasy = bestTime(for: "Easy"), let avgEasy = averageTime(for: "Easy") {
                        HStack {
                            Label("Easy Best: \(bestEasy)", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            Spacer()
                            
                            Label("Avg: \(avgEasy)", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    // Medium difficulty
                    if let bestMedium = bestTime(for: "Medium"), let avgMedium = averageTime(for: "Medium") {
                        HStack {
                            Label("Medium Best: \(bestMedium)", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            
                            Spacer()
                            
                            Label("Avg: \(avgMedium)", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    // Hard difficulty
                    if let bestHard = bestTime(for: "Hard"), let avgHard = averageTime(for: "Hard") {
                        HStack {
                            Label("Hard Best: \(bestHard)", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            
                            Spacer()
                            
                            Label("Avg: \(avgHard)", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            
            if showingStats {
                if game?.name.lowercased() == "pips" {
                    iOS26TimeBasedChart(
                        groupedResults: monthGroupedResults,
                        gameColor: gameColor
                    )
                    .frame(height: 200)
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing).combined(with: .opacity),
                        removal: .push(from: .leading).combined(with: .opacity)
                    ))
                } else {
                    iOS26PerformanceChart(
                        results: monthResults,
                        gameColor: gameColor
                    )
                    .frame(height: 200)
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing).combined(with: .opacity),
                        removal: .push(from: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - Legacy Implementation
    private var legacyHistoryView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Stats header
                HStack(spacing: Spacing.lg) {
                    StatBox(
                        value: "\(streak.currentStreak)",
                        label: "Current",
                        color: streak.isActive ? .green : .orange
                    )
                    
                    StatBox(
                        value: "\(streak.maxStreak)",
                        label: "Best",
                        color: gameColor
                    )
                    
                    StatBox(
                        value: streak.completionPercentage,
                        label: "Success",
                        color: .blue
                    )
                }
                
                // Month navigation
                monthNavigation
                
                // Calendar grid
                calendarGrid
                
                // Month summary
                if !monthResults.isEmpty {
                    monthSummary
                }
            }
            .padding()
        }
        .navigationTitle(streak.gameName.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            
            Spacer()
            
            Button {
                withAnimation {
                    if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth),
                       nextMonth <= Date() {
                        selectedMonth = nextMonth
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.blue)
            }
            .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
        }
    }
    
    private var calendarGrid: some View {
        VStack(spacing: Spacing.sm) {
            // Weekday headers
            HStack(spacing: Spacing.xs) {
                ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7),
                spacing: Spacing.xs
            ) {
                ForEach(Array(calendarDays().enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            result: result(for: date),
                            groupedResult: groupedResult(for: date),
                            gameColor: gameColor
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }
    
    private var monthSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Month Summary")
                .font(.headline)
            
            HStack {
                Label("\(totalGamesPlayed) games played", systemImage: "gamecontroller")
                    .font(.subheadline)
                
                Spacer()
                
                Label("\(totalGamesCompleted) completed", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }
    
    private var totalGamesPlayed: Int {
        // For Pips (grouped results), only count grouped results
        // For other games (individual results), count individual results
        if game?.name.lowercased() == "pips" {
            return monthGroupedResults.count
        } else {
            return monthResults.count
        }
    }
    
    private var totalGamesCompleted: Int {
        // For Pips (grouped results), only count grouped results
        // For other games (individual results), count individual results
        if game?.name.lowercased() == "pips" {
            return monthGroupedResults.filter { $0.completionStatus.contains("Completed") }.count
        } else {
            return monthResults.filter(\.completed).count
        }
    }
    
    // MARK: - Time-based Performance Metrics for Pips (by difficulty)
    private func bestTime(for difficulty: String) -> String? {
        guard game?.name.lowercased() == "pips" else { return nil }
        
        let difficultyTimes = monthGroupedResults.flatMap { $0.results }
            .filter { $0.parsedData["difficulty"]?.lowercased() == difficulty.lowercased() }
            .filter(\.completed)
            .compactMap { $0.parsedData["time"] }
        
        guard !difficultyTimes.isEmpty else { return nil }
        
        // Convert times to seconds for comparison
        let timesInSeconds = difficultyTimes.compactMap { timeString in
            let components = timeString.split(separator: ":")
            if components.count == 2,
               let minutes = Int(components[0]),
               let seconds = Int(components[1]) {
                return minutes * 60 + seconds
            }
            return nil
        }
        
        guard let bestSeconds = timesInSeconds.min() else { return nil }
        
        let minutes = bestSeconds / 60
        let seconds = bestSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func averageTime(for difficulty: String) -> String? {
        guard game?.name.lowercased() == "pips" else { return nil }
        
        let difficultyTimes = monthGroupedResults.flatMap { $0.results }
            .filter { $0.parsedData["difficulty"]?.lowercased() == difficulty.lowercased() }
            .filter(\.completed)
            .compactMap { $0.parsedData["time"] }
        
        guard !difficultyTimes.isEmpty else { return nil }
        
        // Convert times to seconds for calculation
        let timesInSeconds = difficultyTimes.compactMap { timeString in
            let components = timeString.split(separator: ":")
            if components.count == 2,
               let minutes = Int(components[0]),
               let seconds = Int(components[1]) {
                return minutes * 60 + seconds
            }
            return nil
        }
        
        guard !timesInSeconds.isEmpty else { return nil }
        
        let averageSeconds = timesInSeconds.reduce(0, +) / timesInSeconds.count
        let minutes = averageSeconds / 60
        let seconds = averageSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Helper Methods
    private func calendarDays() -> [Date?] {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month.start) - 1
        let numberOfDays = calendar.range(of: .day, in: .month, for: selectedMonth)?.count ?? 0
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: month.start) {
                days.append(date)
            }
        }
        
        // Fill out the week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func result(for date: Date) -> GameResult? {
        let calendar = Calendar.current
        return monthResults.first { result in
            calendar.isDate(result.date, inSameDayAs: date)
        }
    }
    
    private func groupedResult(for date: Date) -> GroupedGameResult? {
        let calendar = Calendar.current
        return monthGroupedResults.first { groupedResult in
            calendar.isDate(groupedResult.date, inSameDayAs: date)
        }
    }
    
    private var monthSuccessRate: String {
        guard !monthResults.isEmpty else { return "0%" }
        let completed = monthResults.filter(\.completed).count
        let rate = Double(completed) / Double(monthResults.count) * 100
        return String(format: "%.0f%%", rate)
    }
    
    private var averageScore: String {
        let scores = monthResults.compactMap { $0.score }
        guard !scores.isEmpty else { return "—" }
        let average = Double(scores.reduce(0, +)) / Double(scores.count)
        return String(format: "%.1f", average)
    }
}

// MARK: - Supporting Views

// Legacy Stat Box (for pre-iOS 26)
struct StatBox: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
    }
}

// Legacy Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let result: GameResult?
    let groupedResult: GroupedGameResult?
    let gameColor: Color
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: isToday ? 2 : 0)
                )
            
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(textColor)
                
                // Show indicators for grouped results
                if let groupedResult = groupedResult {
                    HStack(spacing: 2) {
                        if groupedResult.hasEasy {
                            Circle().fill(.green).frame(width: 4, height: 4)
                        }
                        if groupedResult.hasMedium {
                            Circle().fill(.yellow).frame(width: 4, height: 4)
                        }
                        if groupedResult.hasHard {
                            Circle().fill(.orange).frame(width: 4, height: 4)
                        }
                    }
                } else if let result = result {
                    Circle()
                        .fill(result.completed ? Color.green : Color.red.opacity(0.7))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 44)
    }
    
    private var backgroundColor: Color {
        if let groupedResult = groupedResult {
            return groupedResult.completionStatus.contains("Completed") ? gameColor.opacity(0.2) : Color(.systemGray6)
        } else if let result = result {
            return result.completed ? gameColor.opacity(0.2) : Color(.systemGray6)
        }
        return Color.clear
    }
    
    private var borderColor: Color {
        isToday ? .blue : .clear
    }
    
    private var textColor: Color {
        (groupedResult != nil || result != nil) ? .primary : .secondary
    }
}

// MARK: - iOS 26 Supporting Views
@available(iOS 26.0, *)
struct iOS26StatBox: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image.safeSystemName(icon, fallback: "chart.bar")
                .font(.title2)
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: isHovered)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .shadow(
                    color: isHovered ? color.opacity(0.15) : .black.opacity(0.05),
                    radius: isHovered ? 8 : 4,
                    y: isHovered ? 4 : 2
                )
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .hoverEffect(.lift)
    }
}

@available(iOS 26.0, *)
struct iOS26CalendarDayView: View {
    let date: Date
    let result: GameResult?
    let gameColor: Color
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
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
                        .font(.system(.body, design: .rounded).weight(isToday ? .bold : .medium))
                        .foregroundStyle(textColor)
                    
                    if let result = result {
                        Circle()
                            .fill(result.completed ? Color.green : Color.red.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(height: 48)
            .scaleEffect(isHovered ? 1.1 : (isSelected ? 1.05 : 1.0))
            .shadow(
                color: isHovered ? gameColor.opacity(0.2) : .clear,
                radius: isHovered ? 4 : 0
            )
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
    
    private var backgroundColor: Color {
        if let result = result {
            return result.completed ? gameColor.opacity(0.15) : Color.red.opacity(0.1)
        }
        return Color(.systemGray6)
    }
    
    private var textColor: Color {
        if isToday { return .blue }
        if result != nil { return .primary }
        return .secondary
    }
}

@available(iOS 26.0, *)
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
                        .font(.caption)
                        .foregroundStyle(result.completed ? .green : .red)
                    
                    if let score = result.score {
                        Text("Score: \(score)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Use safe unwrapping for displayScore
            Text(result.displayScore)
                .font(.title3.weight(.bold))
                .foregroundStyle(gameColor)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

@available(iOS 26.0, *)
struct iOS26SelectedDateGroupedDetail: View {
    let date: Date
    let groupedResult: GroupedGameResult
    let gameColor: Color
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            if isExpanded {
                expandedContentView
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
    
    private var headerView: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 16) {
                dateInfoView
                Spacer()
                difficultyIndicatorsView
                chevronView
            }
        }
        .buttonStyle(.plain)
    }
    
    private var dateInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline.weight(.semibold))
            
            HStack(spacing: 8) {
                completionStatusView
                if let bestTime = groupedResult.bestTime {
                    Text("• \(bestTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var completionStatusView: some View {
        Label(
            groupedResult.completionStatus,
            systemImage: completionIcon
        )
        .font(.caption)
        .foregroundStyle(completionColor)
    }
    
    private var completionIcon: String {
        let completedCount = groupedResult.results.filter(\.completed).count
        
        switch completedCount {
        case 3:
            return "trophy.fill" // Gold - all 3 completed
        case 2:
            return "medal.fill" // Silver - 2/3 completed
        case 1:
            return "rosette" // Bronze - 1/3 completed
        default:
            return "circle" // None completed
        }
    }
    
    private var completionColor: Color {
        let completedCount = groupedResult.results.filter(\.completed).count
        
        switch completedCount {
        case 3:
            return .yellow // Gold
        case 2:
            return .gray // Silver
        case 1:
            return .brown // Bronze
        default:
            return .secondary
        }
    }
    
    private var difficultyIndicatorsView: some View {
        HStack(spacing: 4) {
            if groupedResult.hasEasy {
                Circle().fill(.green).frame(width: 8, height: 8)
            }
            if groupedResult.hasMedium {
                Circle().fill(.yellow).frame(width: 8, height: 8)
            }
            if groupedResult.hasHard {
                Circle().fill(.orange).frame(width: 8, height: 8)
            }
        }
    }
    
    private var chevronView: some View {
        Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
    
    private var expandedContentView: some View {
        VStack(spacing: 8) {
            ForEach(Array(groupedResult.results.enumerated()), id: \.element.id) { index, result in
                DifficultyResultRowView(result: result)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

@available(iOS 26.0, *)
struct DifficultyResultRowView: View {
    let result: GameResult
    
    var body: some View {
        HStack {
            Circle()
                .fill(difficultyColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(difficultyText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Text(result.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }
    
    private var difficultyColor: Color {
        guard let difficulty = result.parsedData["difficulty"] else { return .gray }
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .yellow
        case "hard": return .orange
        default: return .gray
        }
    }
    
    private var difficultyText: String {
        guard let difficulty = result.parsedData["difficulty"],
              let time = result.parsedData["time"] else { return "" }
        return "\(difficulty) - \(time)"
    }
}

@available(iOS 26.0, *)
struct iOS26PerformanceChart: View {
    let results: [GameResult]
    let gameColor: Color
    
    var body: some View {
        Chart(results) { result in
            if let score = result.score {
                LineMark(
                    x: .value("Date", result.date),
                    y: .value("Score", score)
                )
                .foregroundStyle(gameColor)
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Date", result.date),
                    y: .value("Score", score)
                )
                .foregroundStyle(result.completed ? Color.green : Color.red)
                .symbolSize(100)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

@available(iOS 26.0, *)
struct iOS26TimeBasedChart: View {
    let groupedResults: [GroupedGameResult]
    let gameColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Time-based performance summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Times")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        if let bestEasy = bestTime(for: "Easy") {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Easy")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(bestEasy)
                                    .font(.caption.weight(.medium))
                            }
                        }
                        
                        if let bestMedium = bestTime(for: "Medium") {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Medium")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text(bestMedium)
                                    .font(.caption.weight(.medium))
                            }
                        }
                        
                        if let bestHard = bestTime(for: "Hard") {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hard")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text(bestHard)
                                    .font(.caption.weight(.medium))
                            }
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(totalCompleted)/\(totalPossible)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(gameColor)
                }
            }
            
            // Simple completion chart
            Chart(groupedResults.prefix(7)) { groupedResult in
                let completedCount = groupedResult.results.filter(\.completed).count
                let totalCount = groupedResult.results.count
                let completionRate = Double(completedCount) / Double(totalCount)
                
                BarMark(
                    x: .value("Date", groupedResult.date),
                    y: .value("Completion", completionRate)
                )
                .foregroundStyle(gameColor.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day())
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYScale(domain: 0...1)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
    
    private func bestTime(for difficulty: String) -> String? {
        let times = groupedResults.flatMap { $0.results }
            .filter { $0.parsedData["difficulty"]?.lowercased() == difficulty.lowercased() }
            .filter(\.completed)
            .compactMap { $0.parsedData["time"] }
        
        guard !times.isEmpty else { return nil }
        
        // Convert times to seconds for comparison
        let timesInSeconds = times.compactMap { timeString in
            let components = timeString.split(separator: ":")
            if components.count == 2,
               let minutes = Int(components[0]),
               let seconds = Int(components[1]) {
                return minutes * 60 + seconds
            }
            return nil
        }
        
        guard let bestSeconds = timesInSeconds.min() else { return nil }
        
        let minutes = bestSeconds / 60
        let seconds = bestSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var totalCompleted: Int {
        groupedResults.flatMap { $0.results }.filter(\.completed).count
    }
    
    private var totalPossible: Int {
        groupedResults.flatMap { $0.results }.count
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StreakHistoryView(
            streak: GameStreak(
                gameId: Game.wordle.id,
                gameName: "wordle",
                currentStreak: 15,
                maxStreak: 23,
                totalGamesPlayed: 100,
                totalGamesCompleted: 85,
                lastPlayedDate: Date(),
                streakStartDate: Date().addingTimeInterval(-15 * 24 * 60 * 60)
            )
        )
        .environment(AppState())
        .environmentObject(ThemeManager.shared)
    }
}
