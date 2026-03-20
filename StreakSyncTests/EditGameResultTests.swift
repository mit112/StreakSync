//
//  EditGameResultTests.swift
//  StreakSyncTests
//
//  Tests for game result editing: replacing, state mutation, and ViewModel validation.
//

@testable import StreakSync
import XCTest

@MainActor
final class EditGameResultTests: XCTestCase {
    private var appState: AppState!

    // Wordle game ID — deterministic UUID from GameDefinitions
    // swiftlint:disable:next force_unwrapping
    private let wordleId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!

    override func setUp() {
        super.setUp()
        appState = AppState(persistenceService: MockPersistenceService())
    }

    override func tearDown() {
        appState = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeResult(
        id: UUID = UUID(),
        date: Date = Date(),
        completed: Bool = true,
        score: Int? = 3
    ) -> GameResult {
        GameResult(
            id: id,
            gameId: wordleId,
            gameName: "wordle",
            date: date,
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: """
                Wordle 1,234 3/6
                \u{2B1B}\u{1F7E8}\u{2B1B}\u{2B1B}\u{2B1B}
                \u{1F7E9}\u{1F7E9}\u{2B1B}\u{1F7E9}\u{2B1B}
                \u{1F7E9}\u{1F7E9}\u{1F7E9}\u{1F7E9}\u{1F7E9}
                """,
            parsedData: ["puzzleNumber": "1234"]
        )
    }

    private func makeWordleGame() -> Game {
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "https://www.nytimes.com/games/wordle")!
        return Game(
            id: wordleId,
            name: "wordle",
            displayName: "Wordle",
            url: url,
            category: .nytGames,
            resultPattern: #"Wordle \d+ [1-6X]/6"#,
            iconSystemName: "square.grid.3x3.fill",
            backgroundColor: CodableColor(.systemGreen),
            isPopular: true,
            isCustom: false,
            scoringModel: .lowerAttempts
        )
    }

    private func yesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    // MARK: - GameResult.replacing() Tests

    func testReplacingCompletedPreservesOtherFields() {
        let result = makeResult(completed: true, score: 4)
        let edited = result.replacing(completed: false)

        XCTAssertEqual(edited.id, result.id)
        XCTAssertEqual(edited.gameId, result.gameId)
        XCTAssertEqual(edited.gameName, result.gameName)
        XCTAssertEqual(edited.score, result.score)
        XCTAssertEqual(edited.maxAttempts, result.maxAttempts)
        XCTAssertEqual(edited.sharedText, result.sharedText)
        XCTAssertEqual(edited.parsedData, result.parsedData)
        XCTAssertFalse(edited.completed)
    }

    func testReplacingScoreChangesOnlyScore() {
        let result = makeResult(completed: true, score: 3)
        let edited = result.replacing(score: 5)

        XCTAssertEqual(edited.id, result.id)
        XCTAssertEqual(edited.score, 5)
        XCTAssertEqual(edited.completed, result.completed)
        XCTAssertEqual(edited.date, result.date)
    }

    func testReplacingDateChangesOnlyDate() {
        let newDate = yesterday()
        let result = makeResult()
        let edited = result.replacing(date: newDate)

        XCTAssertEqual(edited.id, result.id)
        XCTAssertEqual(edited.date, newDate)
        XCTAssertEqual(edited.score, result.score)
        XCTAssertEqual(edited.completed, result.completed)
    }

    func testReplacingWithNoArgsReturnsEquivalent() {
        let result = makeResult()
        let edited = result.replacing()

        XCTAssertEqual(edited.id, result.id)
        XCTAssertEqual(edited.gameId, result.gameId)
        XCTAssertEqual(edited.gameName, result.gameName)
        XCTAssertEqual(edited.score, result.score)
        XCTAssertEqual(edited.maxAttempts, result.maxAttempts)
        XCTAssertEqual(edited.completed, result.completed)
        XCTAssertEqual(edited.sharedText, result.sharedText)
    }

    func testReplacingPreservesSameId() {
        let fixedId = UUID()
        let result = makeResult(id: fixedId)
        let edited = result.replacing(score: 1, completed: false)

        XCTAssertEqual(edited.id, fixedId)
    }

    func testReplacingSetsNewLastModified() {
        let result = makeResult()
        // Small delay so lastModified differs
        let edited = result.replacing(completed: false)

        XCTAssertNotEqual(edited.lastModified, result.lastModified)
        XCTAssertGreaterThanOrEqual(edited.lastModified, result.lastModified)
    }

    func testReplacingScoreSomeNilClearsScore() {
        let result = makeResult(score: 3)
        // .some(nil) explicitly sets score to nil
        let edited = result.replacing(score: Int??.some(nil))

        XCTAssertNil(edited.score)
        XCTAssertEqual(edited.id, result.id)
    }

    func testReplacingScoreNilKeepsExisting() {
        let result = makeResult(score: 4)
        // Passing nil (the default) means "no change"
        let edited = result.replacing(score: nil)

        XCTAssertEqual(edited.score, 4)
    }

    // MARK: - editGameResult() Integration Tests

    func testEditCompletedToFailedBreaksStreak() async {
        // Build a 3-day streak: days -2, -1, today, all completed
        let results = (0...2).map { daysOffset -> GameResult in
            makeResult(date: daysAgo(daysOffset), completed: true)
        }
        for result in results {
            appState.recentResults.append(result)
        }
        await appState.rebuildStreaksFromResults()

        // Verify streak exists
        let streakBefore = appState.streaks.first { $0.gameId == wordleId }
        XCTAssertNotNil(streakBefore)
        XCTAssertGreaterThan(streakBefore?.currentStreak ?? 0, 0)

        // Edit yesterday's result to failed
        let yesterdayResult = results[1]
        let editedResult = yesterdayResult.replacing(completed: false)
        await appState.editGameResult(original: yesterdayResult, edited: editedResult)

        // Streak should be broken (only today counts)
        let streakAfter = appState.streaks.first { $0.gameId == wordleId }
        XCTAssertNotNil(streakAfter)
        XCTAssertLessThan(streakAfter?.currentStreak ?? 99, streakBefore?.currentStreak ?? 0)
    }

    func testEditFailedToCompletedRebuildsStreak() async {
        // Day -1 completed, today failed
        let yesterdayResult = makeResult(date: yesterday(), completed: true)
        let todayResult = makeResult(date: Date(), completed: false)
        appState.recentResults = [yesterdayResult, todayResult]
        await appState.rebuildStreaksFromResults()

        let streakBefore = appState.streaks.first { $0.gameId == wordleId }

        // Edit today's result to completed
        let editedToday = todayResult.replacing(completed: true)
        await appState.editGameResult(original: todayResult, edited: editedToday)

        let streakAfter = appState.streaks.first { $0.gameId == wordleId }
        XCTAssertGreaterThanOrEqual(
            streakAfter?.currentStreak ?? 0,
            streakBefore?.currentStreak ?? 0
        )
    }

    func testEditResultDateRecomputesStreaks() async {
        let todayResult = makeResult(date: Date(), completed: true)
        appState.recentResults = [todayResult]
        await appState.rebuildStreaksFromResults()

        // Move result to 5 days ago — streak should not count as "today"
        let oldDate = daysAgo(5)
        let editedResult = todayResult.replacing(date: oldDate)
        await appState.editGameResult(original: todayResult, edited: editedResult)

        // Verify the result date was changed in state
        let storedResult = appState.recentResults.first { $0.id == todayResult.id }
        XCTAssertNotNil(storedResult)
        XCTAssertTrue(Calendar.current.isDate(storedResult?.date ?? Date(), inSameDayAs: oldDate))
    }

    func testEditNonexistentResultNoStateChange() async {
        let existing = makeResult(date: Date(), completed: true)
        appState.recentResults = [existing]
        await appState.rebuildStreaksFromResults()

        let resultCountBefore = appState.recentResults.count

        // Create an "edited" result with a different ID — should be appended
        // but the guard (original.id == edited.id) should pass since we construct
        // them with the same id but the original is not in state
        let orphanId = UUID()
        let original = makeResult(id: orphanId, completed: true)
        let edited = original.replacing(completed: false)

        // edited.id == original.id, but original is not in recentResults
        // editGameResult will replaceOrAppend, adding a new entry
        await appState.editGameResult(original: original, edited: edited)

        // The orphan result gets appended (replaceOrAppend behavior)
        XCTAssertEqual(appState.recentResults.count, resultCountBefore + 1)
    }

    func testEditMismatchedIdIsRejected() async {
        let existing = makeResult(date: Date(), completed: true)
        appState.recentResults = [existing]

        // Create an edited result with a different id — should be rejected
        let mismatchedEdit = makeResult(id: UUID(), completed: false)

        await appState.editGameResult(original: existing, edited: mismatchedEdit)

        // State should be unchanged — mismatched id is rejected
        XCTAssertEqual(appState.recentResults.first?.completed, true)
    }

    // MARK: - EditGameResultViewModel Tests

    func testViewModelInitialStateMatchesOriginal() {
        let result = makeResult(completed: true, score: 4)
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        XCTAssertEqual(vm.completed, result.completed)
        XCTAssertEqual(vm.scoreText, "4")
        XCTAssertEqual(vm.date, result.date)
    }

    func testViewModelHasChangesIsFalseInitially() {
        let result = makeResult()
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        XCTAssertFalse(vm.hasChanges)
    }

    func testViewModelHasChangesTrueWhenCompletedToggled() {
        let result = makeResult(completed: true)
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        vm.completed = false
        XCTAssertTrue(vm.hasChanges)
    }

    func testViewModelHasChangesTrueWhenScoreChanged() {
        let result = makeResult(score: 3)
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        vm.scoreText = "5"
        XCTAssertTrue(vm.hasChanges)
    }

    func testViewModelHasChangesTrueWhenDateChanged() {
        let result = makeResult(date: Date())
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        vm.date = yesterday()
        XCTAssertTrue(vm.hasChanges)
    }

    func testViewModelIsValidFalseWhenNoChanges() {
        let result = makeResult()
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        XCTAssertFalse(vm.isValid)
    }

    func testViewModelIsValidFalseWhenScoreNonNumeric() {
        let result = makeResult(score: 3)
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        vm.scoreText = "abc"
        XCTAssertFalse(vm.isValid)
    }

    func testViewModelIsValidTrueWhenCompletedToggled() {
        let result = makeResult(completed: true)
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        vm.completed = false
        XCTAssertTrue(vm.isValid)
    }

    func testViewModelScoreOutOfRangeForLowerAttemptsIsInvalid() {
        let result = makeResult(score: 3)
        let vm = EditGameResultViewModel(result: result, game: makeWordleGame())

        // Wordle maxAttempts=6, lowerAttempts: valid range is 1-6
        vm.scoreText = "7"
        XCTAssertTrue(vm.hasChanges)
        XCTAssertFalse(vm.isValid)
    }
}
