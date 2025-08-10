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
            // Weekday headers
            HStack(spacing: 8) {
                ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                ForEach(calendarDays(), id: \.self) { date in
                    if let date = date {
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
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
            
            // Selected date detail
            if let selected = selectedDate,
               let result = result(for: selected) {
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
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
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
                Label("\(monthResults.count) games played", systemImage: "gamecontroller.fill")
                    .font(.subheadline)
                
                Spacer()
                
                Label("\(monthResults.filter(\.completed).count) completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            
            if showingStats {
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
                ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { day in
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
                ForEach(calendarDays(), id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            result: result(for: date),
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
                Label("\(monthResults.count) games played", systemImage: "gamecontroller")
                    .font(.subheadline)
                
                Spacer()
                
                Label("\(monthResults.filter(\.completed).count) completed", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
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
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(height: 44)
    }
    
    private var backgroundColor: Color {
        if let result = result {
            return result.completed ? gameColor.opacity(0.2) : Color(.systemGray6)
        }
        return Color.clear
    }
    
    private var borderColor: Color {
        isToday ? .blue : .clear
    }
    
    private var textColor: Color {
        result != nil ? .primary : .secondary
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
            Image(systemName: icon)
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
