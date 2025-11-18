# Game Results Graph Presentation - Comprehensive Documentation

## Table of Contents
1. [Overview](#overview)
2. [Game Result Structure](#game-result-structure)
3. [Scoring Models](#scoring-models)
4. [Chart Implementations](#chart-implementations)
5. [Game-Specific Graph Handling](#game-specific-graph-handling)
6. [Chart Components](#chart-components)
7. [Data Aggregation](#data-aggregation)
8. [Visual Design](#visual-design)

---

## Overview

StreakSync presents game results in graphs using SwiftUI's `Charts` framework (iOS 16+) with fallback implementations for older iOS versions. The system dynamically adapts chart scales, colors, and data presentation based on each game's scoring model and result structure.

### Key Features
- **Dynamic Scaling**: Charts automatically adjust Y-axis ranges based on actual score values
- **Game-Specific Handling**: Different games have specialized chart configurations
- **Color Coding**: Green for completed games, red for failed attempts
- **Interactive Elements**: Tap to select bars, view details, navigate to full history
- **Multi-View Support**: Charts appear in Analytics Dashboard, Game Detail Views, and Streak History

---

## Game Result Structure

### Core Model: `GameResult`

```swift
struct GameResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let gameId: UUID
    let gameName: String
    let date: Date
    let score: Int?              // The actual score value (varies by game type)
    let maxAttempts: Int         // Maximum possible attempts/score
    let completed: Bool          // Whether the game was completed successfully
    let sharedText: String       // Original shared text from the game
    let parsedData: [String: String]  // Game-specific metadata
}
```

### What Each Result Represents by Game Type

#### 1. **Wordle / Nerdle** (Lower Attempts Model)
- **Score**: Number of guesses used (1-6)
- **Max Attempts**: 6
- **Completed**: `true` if score exists, `false` if "X/6"
- **Graph Display**: Bar height = number of guesses (lower is better)
- **Failed Results**: Displayed as `maxAttempts + 1` (7) with red color

#### 2. **Quordle** (Lower Attempts Model)
- **Score**: Average of 4 puzzle scores (if all completed)
- **Max Attempts**: 9
- **Completed**: `true` only if all 4 puzzles completed
- **Graph Display**: Average score across puzzles
- **Special**: Individual puzzle scores stored in `parsedData["score1-4"]`
- **Failed Puzzles**: Represented as "failed" in parsedData

#### 3. **Octordle** (Lower Attempts Model)
- **Score**: Total score from "Score: XX" line
- **Max Attempts**: Variable (based on total score)
- **Completed**: `true` only if NO red squares (🟥) appear
- **Graph Display**: Total score (lower is better)
- **Special**: Tracks completed vs failed words separately

#### 4. **LinkedIn Zip / Tango / Queens / Crossclimb** (Lower Time Seconds Model)
- **Score**: Time in seconds (e.g., "1:23" = 83 seconds)
- **Max Attempts**: 0 (not applicable for time-based games)
- **Completed**: Always `true` (if parsed successfully)
- **Graph Display**: Time in seconds on Y-axis
- **Y-Axis Formatting**: Displays as "M:SS" format for values ≥ 60 seconds
- **Special Handling**: Chart max value calculated from actual times, not fixed

#### 5. **LinkedIn Pinpoint** (Lower Guesses Model)
- **Score**: Number of guesses used (1-5)
- **Max Attempts**: 5
- **Completed**: `true` if found the answer (indicated by 📌 emoji)
- **Graph Display**: Number of guesses (lower is better)
- **Chart Max**: Fixed at 5

#### 6. **NYT Strands** (Lower Hints Model)
- **Score**: Number of hints used (0-10)
- **Max Attempts**: 10
- **Completed**: Always `true` (Strands has no failure state)
- **Graph Display**: Hint count (lower is better, 0 = perfect)
- **Chart Max**: Fixed at 10

#### 7. **Pips** (Lower Time Seconds Model)
- **Score**: Difficulty level (1=Easy, 2=Medium, 3=Hard)
- **Max Attempts**: 3
- **Completed**: Always `true` if parsed
- **Graph Display**: Uses difficulty as score, but time stored in `parsedData["time"]`
- **Special**: Best times tracked separately by difficulty level

#### 8. **Connections** (Higher Is Better Model)
- **Score**: Number of categories solved (0-4)
- **Max Attempts**: 4
- **Completed**: `true` only if all 4 categories solved
- **Graph Display**: Categories solved (higher is better)
- **Special**: Tracks strikes and total guesses separately

#### 9. **Spelling Bee** (Higher Is Better Model)
- **Score**: Points earned (variable, no fixed max)
- **Max Attempts**: 1000 (arbitrary high number)
- **Completed**: `true` if rank is "Genius" or higher
- **Graph Display**: Points score (higher is better)

#### 10. **Mini Crossword** (Lower Time Seconds Model)
- **Score**: Completion time in seconds
- **Max Attempts**: 600 (10 minutes)
- **Completed**: Always `true` if parsed
- **Graph Display**: Time in seconds

---

## Scoring Models

The `ScoringModel` enum determines how scores are interpreted:

```swift
enum ScoringModel: String, Codable, Sendable {
    case lowerAttempts      // Fewer attempts = better (Wordle, Nerdle, Quordle, Octordle)
    case lowerTimeSeconds   // Lower time = better (Zip, Tango, Queens, Crossclimb, Pips, Mini)
    case lowerGuesses       // Fewer guesses = better (Pinpoint)
    case lowerHints         // Fewer hints = better (Strands)
    case higherIsBetter     // Higher score = better (Connections, Spelling Bee)
}
```

### Impact on Charts

1. **Y-Axis Direction**: 
   - Lower-better games: Lower values appear "better" visually
   - Higher-better games: Higher values appear "better" visually

2. **Color Interpretation**:
   - Green: Completed successfully
   - Red: Failed (for games that can fail)
   - All games use same color scheme regardless of scoring model

3. **Best Score Calculation**:
   - Lower-better: `min()` of scores
   - Higher-better: `max()` of scores

---

## Chart Implementations

### 1. Game Detail Performance View (`GameDetailPerformanceView`)

**Location**: `StreakSync/Features/Games/Views/GameDetailPerformanceView.swift`

**Purpose**: Shows last 7 days of performance for a specific game

**Key Features**:
- Always displays exactly 7 days (last week)
- Dynamic Y-axis scaling based on game type
- Interactive bar selection
- Tap to navigate to full history
- Export functionality

**Chart Structure**:
```swift
PerformanceChart {
    - SimpleChartHeader (stats summary)
    - ModernChart (iOS 16+) or LegacyPerformanceIndicators (iOS <16)
    - SelectedBarDetail (when bar is tapped)
}
```

**Dynamic Max Value Calculation**:
```swift
private var chartMaxValue: Int {
    // Time-based games (Zip, Tango, Queens, Crossclimb)
    if timeBasedGame {
        return max(actualScores) + 5 padding
    }
    
    // Fixed max games (Pinpoint, Strands)
    if fixedMaxGame {
        return game.maxAttempts
    }
    
    // Standard games
    return max(maxAttempts from results) + 1
}
```

**Bar Mark Creation**:
```swift
BarMark(
    x: .value("Day", weekdayString),
    y: .value("Score", score ?? maxAttempts + 1)
)
.foregroundStyle(completed ? .green : .red)
```

**Empty Day Handling**:
- Days without games show minimal indicator (0.2 height)
- Uses tertiary color with low opacity
- Still clickable to show "No game played" detail

---

### 2. Analytics Dashboard Chart (`GamePerformanceChartView`)

**Location**: `StreakSync/Features/Analytics/Views/AnalyticsChartSections.swift`

**Purpose**: Shows recent performance in analytics dashboard

**Key Features**:
- Shows last 7 results (not necessarily 7 days)
- Dynamic scaling based on actual scores
- "X" overlay for failed results
- Time formatting for time-based games

**Y-Axis Formatting**:
```swift
.chartYAxis {
    AxisMarks(position: .trailing) { value in
        if let doubleValue = value.as(Double.self) {
            let intVal = Int(doubleValue)
            // Format time-based games as M:SS
            if intVal >= 60 && intVal % 30 == 0 {
                let minutes = intVal / 60
                let seconds = intVal % 60
                Text(String(format: "%d:%02d", minutes, seconds))
            } else {
                Text("\(intVal)")
            }
        }
    }
}
```

**Failed Result Annotation**:
```swift
.annotation(position: .overlay, alignment: .top) {
    if !result.completed {
        Text("X").font(.caption2).foregroundStyle(.secondary)
    }
}
```

---

### 3. Streak History Charts (`StreakHistoryView`)

**Location**: `StreakSync/Features/Streaks/Views/StreakHistoryView.swift`

**Purpose**: Shows historical performance over time

**Chart Types**:

#### A. Standard Score Chart (`iOS26ScoreBasedChart`)
- For games with attempt-based scoring
- Shows individual results as bars
- Color-coded by completion status
- X-axis: Dates
- Y-axis: Score values

#### B. Time-Based Chart (`iOS26TimeBasedChart`)
- For games with time-based scoring (Pips)
- Shows completion rate per puzzle
- Displays best times by difficulty
- Completion percentage bars (0-1 scale)

**Pips-Specific Display**:
```swift
// Shows completion rate for each puzzle
BarMark(
    x: .value("Date", groupedResult.date),
    y: .value("Completion", completionRate)
)

// Best times displayed separately by difficulty
bestTime(for: "Easy")   // Green
bestTime(for: "Medium") // Yellow  
bestTime(for: "Hard")   // Orange
```

---

## Game-Specific Graph Handling

### Time-Based Games (Zip, Tango, Queens, Crossclimb)

**Special Considerations**:
1. **Y-Axis Range**: Calculated from actual time values, not fixed
2. **Default Max**: 30 seconds if no results exist
3. **Padding**: Adds 5 seconds above max for visual spacing
4. **Formatting**: Times ≥ 60 seconds formatted as "M:SS"

**Code Example**:
```swift
if game.name.lowercased() == "linkedinzip" {
    if let maxScore = results.compactMap(\.score).max() {
        return maxScore + 5 // Add padding
    }
    return 30 // Default
}
```

### Fixed Max Games (Pinpoint, Strands)

**Special Considerations**:
1. **Pinpoint**: Fixed max of 5 (guesses)
2. **Strands**: Fixed max of 10 (hints)
3. **No Dynamic Scaling**: Max value doesn't change based on results

**Code Example**:
```swift
if game.name.lowercased() == "linkedinpinpoint" {
    return 5 // Fixed max
}

if game.name.lowercased() == "strands" {
    return 10 // Fixed max
}
```

### Multi-Puzzle Games (Quordle, Octordle)

**Quordle**:
- Displays average score across 4 puzzles
- Individual scores stored in `parsedData`
- Failed if any puzzle failed (average score = nil)

**Octordle**:
- Displays total score from "Score: XX" line
- Tracks completed vs failed words
- Completion status based on presence of red squares (🟥)

### Difficulty-Based Games (Pips)

**Special Handling**:
- Score represents difficulty (1-3)
- Actual performance metric is time (stored separately)
- Charts show completion rate, not time directly
- Best times displayed by difficulty level

---

## Chart Components

### ModernChart (iOS 16+)

**Structure**:
```swift
Chart(dailyResults.indices, id: \.self) { index in
    let daily = dailyResults[index]
    
    if let result = daily.result {
        BarMark(
            x: .value("Day", dayString),
            y: .value("Score", animateChart ? score : 0)
        )
        .foregroundStyle(barColor.gradient)
        .opacity(selectedBar == nil || selectedBar?.date == daily.date ? 1 : 0.5)
        .cornerRadius(4)
    } else {
        // Empty day indicator
        BarMark(
            x: .value("Day", dayString),
            y: .value("Score", animateChart ? 0.2 : 0)
        )
        .foregroundStyle(.tertiary.opacity(0.2))
    }
}
.chartYScale(domain: 0...maxValue)
```

**Features**:
- Animation support (bars grow from 0)
- Selection highlighting (opacity changes)
- Gradient fills for visual appeal
- Rounded corners for modern look

### Legacy Performance Indicators (iOS <16)

**Fallback Implementation**:
- Uses circles instead of bars
- Color-coded by completion status
- Simple day labels below
- No interactivity

---

## Data Aggregation

### Daily Results Structure

```swift
struct DailyResult {
    let date: Date
    let result: GameResult?  // nil if no game played that day
}
```

**Creation Logic**:
```swift
private var dailyResults: [DailyResult] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    // Generate last 7 days
    var last7Days: [Date] = []
    for i in 0..<7 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            last7Days.append(date)
        }
    }
    last7Days.reverse()
    
    // Map each day to its result (if any)
    return last7Days.map { dayStart in
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let dayResult = results.first { result in
            result.date >= dayStart && result.date < dayEnd
        }
        return DailyResult(date: dayStart, result: dayResult)
    }
}
```

### Statistics Calculation

**SimpleStats Structure**:
```swift
struct SimpleStats {
    let gamesPlayed: Int           // Count of results
    let averageScore: String       // Average of completed games
    let bestScore: Int             // Best (lowest for lower-better, highest for higher-better)
    let successRate: String        // Percentage completed
    let completionRatio: Double  // 0.0 to 1.0
}
```

**Calculation Logic**:
```swift
init(from dailyResults: [DailyResult]) {
    let results = dailyResults.compactMap(\.result)
    self.gamesPlayed = results.count
    
    // Average: Only completed games with scores
    let completedResults = results.filter { $0.completed && $0.score != nil }
    if !completedResults.isEmpty {
        let total = completedResults.compactMap(\.score).reduce(0, +)
        let avg = Double(total) / Double(completedResults.count)
        self.averageScore = String(format: "%.1f", avg)
    }
    
    // Best: Minimum for lower-better, maximum for higher-better
    self.bestScore = completedResults.compactMap(\.score).min() ?? 0
    
    // Success rate
    let successCount = results.filter(\.completed).count
    if gamesPlayed > 0 {
        let rate = Double(successCount) / Double(gamesPlayed) * 100
        self.successRate = "\(Int(rate))%"
        self.completionRatio = Double(successCount) / Double(gamesPlayed)
    }
}
```

---

## Visual Design

### Color Scheme

**Completion Status**:
- **Green**: Successfully completed games
- **Red**: Failed attempts (for games that can fail)
- **Tertiary (Low Opacity)**: Empty days (no game played)

**Gradients**:
- Completed bars use `.green.gradient`
- Failed bars use `.red.gradient`
- Streak trends use `.orange.gradient`

### Typography

**Chart Labels**:
- X-axis: `.caption2` font, weekday abbreviations ("Mon", "Tue", etc.)
- Y-axis: `.caption2` font, numeric values
- Selected bar detail: `.caption` font

**Stats Display**:
- Values: `.title2.bold()`
- Labels: `.caption` with `.secondary` foreground
- Tooltips: `.caption2` with `.tertiary` foreground

### Layout

**Chart Dimensions**:
- Height: 120-140 points (varies by view)
- Padding: 16 points around chart
- Bar spacing: Automatic (handled by Charts framework)
- Corner radius: 4-12 points (varies by component)

**Background**:
- `.ultraThinMaterial` for glassmorphism effect
- Subtle shadows for depth
- Border strokes for definition

### Animation

**Chart Appearance**:
```swift
.onAppear {
    withAnimation(.smooth.delay(0.3)) {
        chartHasAppeared = true
    }
}

// Bars animate from 0 to actual value
y: .value("Score", animateChart ? score : 0)
```

**Bar Selection**:
```swift
withAnimation(.smooth) {
    selectedBar = daily
}
```

---

## Summary

The graph presentation system in StreakSync is highly sophisticated, with:

1. **Game-Aware Scaling**: Each game type has appropriate Y-axis ranges
2. **Dynamic Adaptation**: Charts adjust to actual data ranges
3. **Visual Clarity**: Color coding and formatting make results easy to interpret
4. **Interactive Elements**: Tap to explore, navigate to details
5. **Comprehensive Coverage**: Supports 13+ different game types with unique scoring models
6. **Accessibility**: Fallback implementations for older iOS versions
7. **Performance**: Efficient data aggregation and rendering

The system ensures that regardless of whether a game uses attempts, time, hints, or points as its scoring metric, the graphs present the data in a clear, meaningful, and visually appealing way.

