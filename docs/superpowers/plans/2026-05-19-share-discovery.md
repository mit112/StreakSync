# Share-Sheet Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach users how to use the share-sheet flow (new installs + existing users with 0 results), and celebrate their first successful share.

**Architecture:** Two surfaces — a one-time full-screen onboarding sheet triggered from the Dashboard, and a confetti toast triggered from `AppState.addGameResult` on the 0→1 transition. A pure `ShareDiscoveryGate` struct holds the decision logic so it's testable in isolation from SwiftUI views.

**Tech Stack:** SwiftUI (iOS 26+), Swift 6, XCTest. Native SwiftUI `Canvas` + `TimelineView` for confetti — no SPM dependency. `UserDefaults.standard` for two device-local flags. NotificationCenter for the celebration trigger.

**Spec:** `docs/superpowers/specs/2026-05-19-share-discovery-design.md`

---

## File Structure

**New files (4):**

- `StreakSync/Features/Onboarding/Views/ShareDiscoverySheet.swift` — full-screen modal sheet (composes the mockup + copy + CTA).
- `StreakSync/Features/Onboarding/Views/ShareSheetMockup.swift` — illustrative iPhone-shaped mockup of the share-sheet UI with pulsing StreakSync icon.
- `StreakSync/Features/Onboarding/Views/FirstShareCelebrationOverlay.swift` — `ViewModifier` that listens for the celebration notification and renders the banner + confetti.
- `StreakSync/Features/Onboarding/Views/ConfettiView.swift` — `Canvas`-based particle system, respects Reduce Motion.
- `StreakSync/Core/Services/Utilities/ShareDiscoveryGate.swift` — pure decision logic (should-show? should-fire?), trivially testable.
- `StreakSyncTests/ShareDiscoveryGateTests.swift` — unit tests for the gate.
- `StreakSyncTests/FirstShareCelebrationTriggerTests.swift` — unit tests for the AppState 0→1 detection.

**Modified files (5):**

- `StreakSync/Core/Models/Shared/AppConstants.swift` — add `Onboarding` enum (UserDefaults keys) + new `Notification.Name` extension.
- `StreakSync/Features/Dashboard/Views/EmptyStateGuidanceCard.swift` — copy update only.
- `StreakSync/Features/Dashboard/Views/ImprovedDashboardView.swift` — trigger logic + `.sheet(...)`.
- `StreakSync/Features/Settings/Views/SettingsView.swift` — "How StreakSync works" row.
- `StreakSync/Core/State/AppState+ResultAddition.swift` — detect 0→1, post celebration notification, set flag.
- `StreakSync/App/ContentView.swift` — apply `.firstShareCelebration()` modifier to `MainTabView`.

---

## Task 1: Add UserDefaults keys + Notification.Name constants

**Files:**
- Modify: `StreakSync/Core/Models/Shared/AppConstants.swift`

- [ ] **Step 1: Add the `Onboarding` enum and notification name**

In `AppConstants.swift`, after the `NotificationSettings` enum (around line 61), add:

```swift
    // MARK: - Onboarding Keys
    enum Onboarding {
        static let hasSeenShareOnboarding = "hasSeenShareOnboarding"
        static let hasSeenFirstShareCelebration = "hasSeenFirstShareCelebration"
    }
```

Then in the `extension Notification.Name` block at the bottom of the file (around line 78), append:

```swift
    static let appFirstShareCelebrationRequested = Notification.Name("firstShareCelebrationRequested")
```

- [ ] **Step 2: Build to verify compilation**

Run via XcodeBuildMCP:
```
mcp__XcodeBuildMCP__build_sim (uses session defaults)
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add StreakSync/Core/Models/Shared/AppConstants.swift
git commit -m "feat(onboarding): add UserDefaults keys and notification name for share discovery"
```

---

## Task 2: Add ShareDiscoveryGate (pure decision logic) — TDD

**Files:**
- Create: `StreakSync/Core/Services/Utilities/ShareDiscoveryGate.swift`
- Create: `StreakSyncTests/ShareDiscoveryGateTests.swift`

- [ ] **Step 1: Write the failing tests first**

Create `StreakSyncTests/ShareDiscoveryGateTests.swift`:

```swift
//
//  ShareDiscoveryGateTests.swift
//  StreakSync
//
//  Tests for the share-discovery decision gate
//

import XCTest
@testable import StreakSync

final class ShareDiscoveryGateTests: XCTestCase {

    // MARK: - shouldShowOnboarding

    func testShouldShowOnboarding_zeroResultsAndUnseen_returnsTrue() {
        XCTAssertTrue(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 0, hasSeen: false))
    }

    func testShouldShowOnboarding_zeroResultsButAlreadySeen_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 0, hasSeen: true))
    }

    func testShouldShowOnboarding_hasResults_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 1, hasSeen: false))
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 42, hasSeen: false))
    }

    func testShouldShowOnboarding_hasResultsAndSeen_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 5, hasSeen: true))
    }

    // MARK: - shouldFireCelebration

    func testShouldFireCelebration_firstResultAndUnseen_returnsTrue() {
        XCTAssertTrue(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 0, hasSeen: false, isGuest: false))
    }

    func testShouldFireCelebration_alreadySeen_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 0, hasSeen: true, isGuest: false))
    }

    func testShouldFireCelebration_notFirstResult_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 1, hasSeen: false, isGuest: false))
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 10, hasSeen: false, isGuest: false))
    }

    func testShouldFireCelebration_guestMode_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 0, hasSeen: false, isGuest: true))
    }
}
```

- [ ] **Step 2: Run the tests — verify they fail**

Run via XcodeBuildMCP `test_sim` with `-only-testing:StreakSyncTests/ShareDiscoveryGateTests`.
Expected: FAIL ("Cannot find 'ShareDiscoveryGate' in scope").

- [ ] **Step 3: Implement the gate**

Create `StreakSync/Core/Services/Utilities/ShareDiscoveryGate.swift`:

```swift
//
//  ShareDiscoveryGate.swift
//  StreakSync
//
//  Pure decision logic for the share-discovery teaching sheet and first-share celebration
//

import Foundation

/// Pure decision logic for share-discovery surfaces. Decoupled from UserDefaults and SwiftUI
/// so it can be exercised in tests without any system dependencies.
enum ShareDiscoveryGate {

    /// Should the first-launch teaching sheet be presented?
    /// True when the user has never logged a result AND has not yet dismissed the sheet.
    static func shouldShowOnboarding(resultsCount: Int, hasSeen: Bool) -> Bool {
        resultsCount == 0 && !hasSeen
    }

    /// Should the first-share celebration fire for this `addGameResult` call?
    /// True when this insertion takes the user from 0 → 1 results, the celebration hasn't
    /// already fired, and the user is not in Guest Mode.
    static func shouldFireCelebration(preInsertCount: Int, hasSeen: Bool, isGuest: Bool) -> Bool {
        preInsertCount == 0 && !hasSeen && !isGuest
    }
}
```

- [ ] **Step 4: Run the tests — verify they pass**

Same `test_sim` invocation.
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add StreakSync/Core/Services/Utilities/ShareDiscoveryGate.swift StreakSyncTests/ShareDiscoveryGateTests.swift
git commit -m "feat(onboarding): add ShareDiscoveryGate decision logic with tests"
```

---

## Task 3: Update EmptyStateGuidanceCard copy

**Files:**
- Modify: `StreakSync/Features/Dashboard/Views/EmptyStateGuidanceCard.swift:16-30`

- [ ] **Step 1: Update the `cardContent` computed property**

Replace the existing `cardContent` block (around lines 16-30) with:

```swift
    private var cardContent: (icon: String, title: String, message: String) {
        if isReturningUser {
            return (
                icon: "arrow.clockwise",
                title: "Reignite Your Streaks!",
                message: "Play a quick game. Tap Share inside the game, then pick StreakSync to log it."
            )
        } else {
            return (
                icon: "sparkles",
                title: "Start Your First Streak!",
                message: "Finish a Wordle. Tap Share inside the game, then pick StreakSync."
            )
        }
    }
```

- [ ] **Step 2: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add StreakSync/Features/Dashboard/Views/EmptyStateGuidanceCard.swift
git commit -m "feat(onboarding): clarify empty-state card copy to point at game's share menu"
```

---

## Task 4: Build ShareSheetMockup view

**Files:**
- Create: `StreakSync/Features/Onboarding/Views/ShareSheetMockup.swift`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p StreakSync/Features/Onboarding/Views
```

- [ ] **Step 2: Implement the mockup**

Create `StreakSync/Features/Onboarding/Views/ShareSheetMockup.swift`:

```swift
//
//  ShareSheetMockup.swift
//  StreakSync
//
//  Illustrative iPhone share-sheet mockup with a highlighted StreakSync icon
//

import SwiftUI

struct ShareSheetMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 12) {
            wordleResultPreview
            shareSheetRow
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var wordleResultPreview: some View {
        VStack(spacing: 6) {
            Text("Wordle 1,234  3/6")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                tileRow(colors: [.gray, .gray, .yellow, .gray, .gray])
                tileRow(colors: [.yellow, .green, .gray, .gray, .gray])
                tileRow(colors: [.green, .green, .green, .green, .green])
            }
        }
    }

    private func tileRow(colors: [Color]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<colors.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tileColor(colors[i]))
                    .frame(width: 22, height: 22)
            }
        }
    }

    private func tileColor(_ c: Color) -> Color {
        switch c {
        case .green: return Color(red: 0.42, green: 0.67, blue: 0.39)
        case .yellow: return Color(red: 0.79, green: 0.71, blue: 0.34)
        default: return Color(red: 0.47, green: 0.49, blue: 0.49)
        }
    }

    private var shareSheetRow: some View {
        HStack(spacing: 10) {
            shareIcon(systemImage: "message.fill", tint: .green, label: "Messages")
            shareIcon(systemImage: "envelope.fill", tint: .blue, label: "Mail")
            streakSyncIcon
            shareIcon(systemImage: "ellipsis", tint: .gray, label: "More")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func shareIcon(systemImage: String, tint: Color, label: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var streakSyncIcon: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.39, green: 0.4, blue: 0.95), Color(red: 0.55, green: 0.36, blue: 0.96)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color.purple.opacity(pulse ? 0.6 : 0.2),
                            radius: pulse ? 14 : 4, x: 0, y: 0)
                    .scaleEffect(pulse ? 1.08 : 1.0)
            }
            Text("StreakSync")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("StreakSync share-sheet icon, highlighted")
    }
}

#Preview {
    ShareSheetMockup()
        .padding()
        .background(Color(.systemGroupedBackground))
}
```

- [ ] **Step 3: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 4: Commit**

```bash
git add StreakSync/Features/Onboarding/Views/ShareSheetMockup.swift
git commit -m "feat(onboarding): add iPhone share-sheet mockup view with pulsing StreakSync icon"
```

---

## Task 5: Build ShareDiscoverySheet (the full modal)

**Files:**
- Create: `StreakSync/Features/Onboarding/Views/ShareDiscoverySheet.swift`

- [ ] **Step 1: Implement the sheet**

Create `StreakSync/Features/Onboarding/Views/ShareDiscoverySheet.swift`:

```swift
//
//  ShareDiscoverySheet.swift
//  StreakSync
//
//  Full-screen teaching sheet for the share-extension flow
//

import SwiftUI

struct ShareDiscoverySheet: View {
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismissEnv

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    ShareSheetMockup()
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        Text("Save your streak in 3 taps")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        Text("Finish a game in Wordle (or any of 16 supported games). Tap **Share**, then pick **StreakSync**. We'll record the result automatically.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }

            Button(action: handleDismiss) {
                Text("Got it")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .buttonStyle(.plain)
            .accessibilityLabel("Got it. Dismiss the share-discovery tutorial.")
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func handleDismiss() {
        HapticManager.shared.trigger(.buttonTap)
        onDismiss()
        dismissEnv()
    }
}

#Preview {
    ShareDiscoverySheet(onDismiss: {})
}
```

- [ ] **Step 2: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add StreakSync/Features/Onboarding/Views/ShareDiscoverySheet.swift
git commit -m "feat(onboarding): add full-screen share-discovery teaching sheet"
```

---

## Task 6: Wire teaching sheet trigger in ImprovedDashboardView

**Files:**
- Modify: `StreakSync/Features/Dashboard/Views/ImprovedDashboardView.swift`

- [ ] **Step 1: Read the current state declarations and onAppear in `ImprovedDashboardView`**

Run:
```bash
grep -n "@State\|@AppStorage\|onAppear\|hasSeenGuidance" StreakSync/Features/Dashboard/Views/ImprovedDashboardView.swift | head -20
```

You should see existing `@State private var hasSeenGuidance` near line 27 and `.onAppear` near line 137. We'll add new state + logic alongside.

- [ ] **Step 2: Add the @State and trigger logic**

Just below the existing `@State private var hasSeenGuidance = ...` line (around line 27), add:

```swift
    @State private var isShowingShareDiscovery: Bool = false
```

Inside the existing `.onAppear` block (find the closure at line ~137), append the gate check. The result count comes from `AppState`; the file already has an `@EnvironmentObject` (or `@Environment`) reference to it — match the existing pattern. If the existing access pattern uses `container.appState.recentResults.count`, use that. The exact line to add at the end of the closure body:

```swift
        // Share-discovery teaching sheet — first qualifying launch only
        let hasSeen = UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenShareOnboarding)
        let count = container.appState.recentResults.count
        if ShareDiscoveryGate.shouldShowOnboarding(resultsCount: count, hasSeen: hasSeen) {
            isShowingShareDiscovery = true
        }
```

If the dashboard accesses `AppState` via a different property name (e.g., `appState` directly, or via a view model), substitute accordingly. Use grep to confirm:

```bash
grep -n "appState\|recentResults" StreakSync/Features/Dashboard/Views/ImprovedDashboardView.swift | head -10
```

- [ ] **Step 3: Attach the sheet modifier**

Find where the view body ends (typically right before the closing brace of `body`, or where other `.sheet(...)` modifiers are attached). Add at the end of the view's modifier chain (sibling of `.onAppear`):

```swift
        .sheet(isPresented: $isShowingShareDiscovery) {
            ShareDiscoverySheet(onDismiss: {
                UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenShareOnboarding)
            })
        }
```

- [ ] **Step 4: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 5: Commit**

```bash
git add StreakSync/Features/Dashboard/Views/ImprovedDashboardView.swift
git commit -m "feat(onboarding): present share-discovery sheet on first qualifying dashboard appearance"
```

---

## Task 7: Add Settings entry for re-opening teaching sheet

**Files:**
- Modify: `StreakSync/Features/Settings/Views/SettingsView.swift`

- [ ] **Step 1: Inspect the existing Settings structure**

Run:
```bash
grep -n "Section\|NavigationLink\|sheet" StreakSync/Features/Settings/Views/SettingsView.swift | head -30
```

Locate a "Help" / "About" / "General" section where this row fits naturally. If there's an existing `Section { ... } header: { Text("Help") }` block, append a row inside it. If not, add a new `Section` near the top of the form, **above** the "About" section.

- [ ] **Step 2: Add state and the row**

Add inside the view's `@State` declarations (top of the struct body):

```swift
    @State private var isShowingShareDiscovery: Bool = false
```

Inside the appropriate `Section` of the body, add a `Button` row:

```swift
                Button {
                    isShowingShareDiscovery = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up.on.square")
                            .foregroundStyle(.accentColor)
                            .frame(width: 28)
                        Text("How StreakSync works")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
```

- [ ] **Step 3: Attach the sheet modifier**

At the end of the view body's modifier chain, add:

```swift
        .sheet(isPresented: $isShowingShareDiscovery) {
            ShareDiscoverySheet(onDismiss: {})
        }
```

(Empty closure on purpose: re-opening from Settings does NOT touch the `hasSeenShareOnboarding` flag.)

- [ ] **Step 4: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 5: Commit**

```bash
git add StreakSync/Features/Settings/Views/SettingsView.swift
git commit -m "feat(onboarding): add settings entry to re-open share-discovery sheet"
```

---

## Task 8: Build ConfettiView (Canvas particle system)

**Files:**
- Create: `StreakSync/Features/Onboarding/Views/ConfettiView.swift`

- [ ] **Step 1: Implement the confetti**

Create `StreakSync/Features/Onboarding/Views/ConfettiView.swift`:

```swift
//
//  ConfettiView.swift
//  StreakSync
//
//  Native SwiftUI confetti — Canvas + TimelineView particle system, no dependencies.
//  Respects Reduce Motion: renders nothing when accessibility setting is enabled.
//

import SwiftUI

struct ConfettiView: View {
    /// When set to true, particles begin animating from `Date.now` for `duration` seconds.
    let isActive: Bool

    /// How long particles animate (seconds). Default 3.0.
    let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date = .distantPast

    private let particleCount = 40
    private let colors: [Color] = [.red, .yellow, .green, .blue, .purple, .pink, .orange]

    var body: some View {
        Group {
            if isActive && !reduceMotion {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(startDate)
                        guard elapsed >= 0, elapsed <= duration else { return }

                        for i in 0..<particleCount {
                            let seed = Double(i)
                            let xFrac = (seed * 0.137).truncatingRemainder(dividingBy: 1.0)
                            let xBase = size.width * xFrac
                            let xDrift = sin(elapsed * 1.5 + seed) * 30
                            let y = size.height * (elapsed / duration) + seed * 7 - 60
                            let rotation = elapsed * (1.0 + seed * 0.3) * .pi
                            let opacity = max(0, 1 - elapsed / duration)

                            var ctx = context
                            ctx.translateBy(x: xBase + xDrift, y: y)
                            ctx.rotate(by: .radians(rotation))
                            let rect = CGRect(x: -4, y: -6, width: 8, height: 12)
                            ctx.fill(
                                Path(roundedRect: rect, cornerRadius: 1),
                                with: .color(colors[i % colors.count].opacity(opacity))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startDate = .now
            }
        }
    }
}

#Preview {
    StatefulPreviewWrapper(false) { binding in
        ZStack {
            Color.black.ignoresSafeArea()
            ConfettiView(isActive: binding.wrappedValue, duration: 3.0)
            VStack {
                Spacer()
                Button("Fire") { binding.wrappedValue = true }
                    .padding()
                    .background(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 80)
            }
        }
    }
}

// Helper for the preview — typical SwiftUI preview state-binding wrapper.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
```

- [ ] **Step 2: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add StreakSync/Features/Onboarding/Views/ConfettiView.swift
git commit -m "feat(onboarding): add Canvas-based confetti view, respects reduce motion"
```

---

## Task 9: Build FirstShareCelebrationOverlay

**Files:**
- Create: `StreakSync/Features/Onboarding/Views/FirstShareCelebrationOverlay.swift`

- [ ] **Step 1: Implement the overlay + ViewModifier**

Create `StreakSync/Features/Onboarding/Views/FirstShareCelebrationOverlay.swift`:

```swift
//
//  FirstShareCelebrationOverlay.swift
//  StreakSync
//
//  Listens for .appFirstShareCelebrationRequested and renders confetti + a transient banner.
//

import SwiftUI

struct FirstShareCelebrationOverlay: ViewModifier {
    @State private var isCelebrating: Bool = false
    @State private var gameName: String = ""

    private let displayDuration: TimeInterval = 3.0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                bannerOverlay
            }
            .overlay {
                ConfettiView(isActive: isCelebrating, duration: displayDuration)
                    .ignoresSafeArea()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appFirstShareCelebrationRequested)) { note in
                handleNotification(note)
            }
    }

    @ViewBuilder
    private var bannerOverlay: some View {
        if isCelebrating {
            HStack(spacing: 10) {
                Text("🎉")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("First streak started!")
                        .font(.subheadline.weight(.semibold))
                    if !gameName.isEmpty {
                        Text(gameName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("First streak started in \(gameName)")
        }
    }

    private func handleNotification(_ note: Notification) {
        let name = (note.userInfo?["gameName"] as? String) ?? ""
        gameName = name
        HapticManager.shared.trigger(.achievement)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isCelebrating = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(displayDuration))
            withAnimation(.easeOut(duration: 0.3)) {
                isCelebrating = false
            }
        }
    }
}

extension View {
    /// Mounts the first-share celebration overlay (confetti + banner).
    /// Place once at the app shell level, above tabs/sheets.
    func firstShareCelebration() -> some View {
        modifier(FirstShareCelebrationOverlay())
    }
}
```

- [ ] **Step 2: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add StreakSync/Features/Onboarding/Views/FirstShareCelebrationOverlay.swift
git commit -m "feat(onboarding): add first-share celebration overlay (confetti + banner)"
```

---

## Task 10: Detect 0→1 transition in AppState+ResultAddition — TDD

**Files:**
- Modify: `StreakSync/Core/State/AppState+ResultAddition.swift`
- Create: `StreakSyncTests/FirstShareCelebrationTriggerTests.swift`

- [ ] **Step 1: Read the current `addGameResult` body to confirm insertion site**

Run:
```bash
grep -n "addGameResult\|recentResults.insert\|postResultAddedNotifications" StreakSync/Core/State/AppState+ResultAddition.swift | head -20
```

You should see (a) `addGameResult` at ~line 16, (b) `self.recentResults.insert(result, at: 0)` at ~line 36, (c) `postResultAddedNotifications(for: result)` at ~line 64.

We will insert celebration-detection at three points:
1. Before `recentResults.insert` — capture `wasFirstResult` boolean.
2. After `postResultAddedNotifications(for: result)` — post the celebration notification + set the flag.

- [ ] **Step 2: Write the failing test first**

Create `StreakSyncTests/FirstShareCelebrationTriggerTests.swift`:

```swift
//
//  FirstShareCelebrationTriggerTests.swift
//  StreakSync
//
//  Verifies that AppState.addGameResult posts the appFirstShareCelebrationRequested
//  notification exactly once on the 0→1 transition.
//

import XCTest
@testable import StreakSync

@MainActor
final class FirstShareCelebrationTriggerTests: XCTestCase {

    private var appState: AppState!
    private var observer: NSObjectProtocol?
    private var notificationCount: Int = 0
    private var capturedGameName: String?

    override func setUp() async throws {
        try await super.setUp()
        // Reset persisted flags
        UserDefaults.standard.removeObject(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        notificationCount = 0
        capturedGameName = nil

        appState = AppState.makeForTesting()  // Use existing test factory; see note below.

        observer = NotificationCenter.default.addObserver(
            forName: .appFirstShareCelebrationRequested,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.notificationCount += 1
            self?.capturedGameName = note.userInfo?["gameName"] as? String
        }
    }

    override func tearDown() async throws {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        appState = nil
        try await super.tearDown()
    }

    func testFirstResultPostsCelebrationNotification() {
        let result = GameResult.sampleWordleWin  // existing fixture; replace if name differs
        _ = appState.addGameResult(result)
        XCTAssertEqual(notificationCount, 1)
        XCTAssertEqual(capturedGameName, result.gameName)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration))
    }

    func testSecondResultDoesNotPostCelebration() {
        _ = appState.addGameResult(GameResult.sampleWordleWin)
        _ = appState.addGameResult(GameResult.sampleConnectionsWin)
        XCTAssertEqual(notificationCount, 1, "Should fire only on the 0→1 transition, not on subsequent adds")
    }

    func testCelebrationDoesNotRepeatIfFlagAlreadySet() {
        UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        _ = appState.addGameResult(GameResult.sampleWordleWin)
        XCTAssertEqual(notificationCount, 0)
    }
}
```

**Note on fixtures:** This test references `AppState.makeForTesting()`, `GameResult.sampleWordleWin`, and `GameResult.sampleConnectionsWin`. Before writing the test, verify these exist:

```bash
grep -rn "makeForTesting\|sampleWordle\|sampleConnections" StreakSyncTests/ | head -10
```

If they don't exist with these exact names, look for equivalent fixtures (any existing test that creates an `AppState` and a `GameResult` shows the right approach) and adapt the test accordingly. **Do not add new test fixtures in this task** — reuse what's there. If no fixtures exist, copy the pattern from `LoadAndAchievementsTests.swift` or `StreakLogicTests.swift`.

- [ ] **Step 3: Run the tests — verify they fail**

```bash
xcodebuild test -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests/FirstShareCelebrationTriggerTests
```

Expected: FAIL — notifications are not yet being posted.

- [ ] **Step 4: Modify `addGameResult` to detect the 0→1 transition**

Open `StreakSync/Core/State/AppState+ResultAddition.swift`. After the duplicate-check guards (just before `// Add result` / `self.recentResults.insert(result, at: 0)`), capture the pre-insert state:

```swift
        // Capture state BEFORE insert for first-share celebration detection
        let celebrationFlagSeen = UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        let shouldFireCelebration = ShareDiscoveryGate.shouldFireCelebration(
            preInsertCount: self.recentResults.count,
            hasSeen: celebrationFlagSeen,
            isGuest: self.isGuestMode
        )
```

Then, immediately AFTER the existing `postResultAddedNotifications(for: result)` call, add:

```swift
        // First-share celebration — fires exactly once on the 0→1 transition (host mode)
        if shouldFireCelebration {
            UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
            NotificationCenter.default.post(
                name: .appFirstShareCelebrationRequested,
                object: nil,
                userInfo: ["gameName": result.gameName]
            )
        }
```

- [ ] **Step 5: Run the tests — verify they pass**

Same `xcodebuild test` command as Step 3.
Expected: PASS (3 tests).

- [ ] **Step 6: Run the full unit-test target to confirm no regression**

```bash
xcodebuild test -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests
```

Expected: All existing tests still pass.

- [ ] **Step 7: Commit**

```bash
git add StreakSync/Core/State/AppState+ResultAddition.swift StreakSyncTests/FirstShareCelebrationTriggerTests.swift
git commit -m "feat(onboarding): post celebration notification on first-share 0→1 transition"
```

---

## Task 11: Mount celebration overlay on ContentView

**Files:**
- Modify: `StreakSync/App/ContentView.swift:36-44`

- [ ] **Step 1: Apply the modifier**

In `ContentView.swift`, locate the `MainTabView()` call (currently at line ~36). It already has `.achievementCelebrations(coordinator:)` and `.sheet(item:)` applied — add `.firstShareCelebration()` as the FIRST modifier (so confetti renders above tab content but below sheets):

Before:
```swift
            MainTabView()
                .achievementCelebrations(coordinator: container.achievementCelebrationCoordinator)
                .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
```

After:
```swift
            MainTabView()
                .firstShareCelebration()
                .achievementCelebrations(coordinator: container.achievementCelebrationCoordinator)
                .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
```

- [ ] **Step 2: Build to verify**

`mcp__XcodeBuildMCP__build_sim` — Expected: SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add StreakSync/App/ContentView.swift
git commit -m "feat(onboarding): mount first-share celebration overlay on main tab view"
```

---

## Task 12: Manual smoke test + full test run

**Files:** none modified.

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild test -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO
```

Expected: All tests pass (including the two new test files and any UI tests).

- [ ] **Step 2: Manual smoke — clean install path**

  1. In the simulator, delete the StreakSync app to clear UserDefaults.
  2. Reinstall via `build_run_sim`.
  3. App launches → onboarding sheet should appear over the Dashboard. Confirm:
     - Mockup is visible and the StreakSync icon is pulsing (or static if you've enabled Reduce Motion in Settings → Accessibility → Motion).
     - "Got it" button dismisses the sheet.
  4. Close the app, reopen — sheet should NOT reappear.

- [ ] **Step 3: Manual smoke — first-share celebration**

  1. With the app freshly launched and 0 results, paste a Wordle result into the iOS share sheet (or trigger via the Share Extension).
  2. Confirm confetti + banner appear, banner shows "First streak started! Wordle", auto-dismisses ~3s.
  3. Share another result — confirm NO celebration fires the second time.

- [ ] **Step 4: Manual smoke — Settings re-access**

  1. Open Settings → "How StreakSync works" → confirm the same sheet opens.
  2. Dismiss it. Confirm the flag is NOT re-set (no behavior change).

- [ ] **Step 5: Manual smoke — Reduce Motion**

  1. Enable Settings → Accessibility → Motion → Reduce Motion.
  2. Open Settings → "How StreakSync works" → confirm the icon is NOT pulsing.
  3. Reset all data via Data Management, fire a result via Share Extension → confirm celebration banner shows but NO confetti.

- [ ] **Step 6: Verify SwiftLint passes**

```bash
swiftlint
```

Expected: no new violations from the touched files.

- [ ] **Step 7: Final commit if any fixes were needed**

If any smoke-test fixes were made, commit them:
```bash
git add -p && git commit -m "fix(onboarding): <describe>"
```

---

## Acceptance Criteria (from spec)

After Task 12 passes:

- [x] A new user installing the app sees the teaching sheet on their first Dashboard appearance.
- [x] An existing user with 0 results sees the teaching sheet on their next Dashboard appearance after the update ships.
- [x] A user who shares a result for the first time (count goes 0 → 1) sees confetti and a banner.
- [x] The teaching sheet never auto-fires twice for the same user.
- [x] The celebration never fires twice for the same user.
- [x] Settings has a "How StreakSync works" row that re-opens the teaching sheet.
- [x] `EmptyStateGuidanceCard`'s message clearly references "tap Share inside the game."
- [x] All UI respects Reduce Motion accessibility setting.
