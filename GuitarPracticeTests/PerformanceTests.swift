import XCTest
import Combine
@testable import GuitarPractice

@MainActor
final class PerformanceTests: XCTestCase {

    // MARK: - Test 1: filteredLibrary performance with 500 items

    func testFilteredLibraryPerformance() {
        let state = TestHelpers.makePopulatedAppState(libraryCount: 500)
        state.searchText = "exercise"
        state.sortOption = .name
        state.sortAscending = true

        measure {
            for _ in 0..<100 {
                let _ = state.filteredLibrary
            }
        }
    }

    // MARK: - Test 2: Timer cascade — count objectWillChange emissions

    func testTimerCascadeRenderCount() async {
        let state = AppState()
        let items = TestHelpers.makeMockLibraryItems(count: 10)
        state.libraryState = .loaded(items)

        var appStateChangeCount = 0
        let appCancellable = state.objectWillChange.sink { _ in
            appStateChangeCount += 1
        }

        var timerChangeCount = 0
        let timerCancellable = state.timerState.objectWillChange.sink { _ in
            timerChangeCount += 1
        }

        state.resumeTimer()

        // Let timer run for 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        state.pauseTimer()

        // Timer should fire on timerState only, NOT on appState
        print("⏱ Timer cascade: appState=\(appStateChangeCount), timerState=\(timerChangeCount) objectWillChange emissions in 2 seconds")
        XCTAssertEqual(appStateChangeCount, 0, "AppState should NOT receive objectWillChange from timer ticks")
        XCTAssertGreaterThan(timerChangeCount, 5, "TimerState should receive objectWillChange from timer ticks")

        appCancellable.cancel()
        timerCancellable.cancel()
    }

    // MARK: - Test 3: filteredLibrary cache efficiency (baseline — no cache yet)

    func testFilteredLibraryCacheEfficiency() {
        let state = TestHelpers.makePopulatedAppState(libraryCount: 500)
        state.searchText = "exercise"
        state.sortOption = .name

        // First call — computes from scratch
        let start1 = CFAbsoluteTimeGetCurrent()
        let result1 = state.filteredLibrary
        let time1 = CFAbsoluteTimeGetCurrent() - start1

        // Second call — should be a cache hit
        let start2 = CFAbsoluteTimeGetCurrent()
        let result2 = state.filteredLibrary
        let time2 = CFAbsoluteTimeGetCurrent() - start2

        print("📊 filteredLibrary: call1=\(String(format: "%.6f", time1))s, call2=\(String(format: "%.6f", time2))s, ratio=\(String(format: "%.1f", time1 / max(time2, 0.000001)))x")
        XCTAssertEqual(result1.count, result2.count)
        // Cache hit should be at least 5x faster
        XCTAssertGreaterThan(time1 / max(time2, 0.000001), 5.0, "Cache hit should be significantly faster than cold compute")
    }

    // MARK: - Test 4: Unrelated state change triggers objectWillChange

    func testUnrelatedChangeTriggersRerender() {
        let state = TestHelpers.makePopulatedAppState(libraryCount: 100)

        var changeCount = 0
        let cancellable = state.objectWillChange.sink { _ in
            changeCount += 1
        }

        // Change search text — relevant to library
        changeCount = 0
        state.searchText = "blues"
        let searchChanges = changeCount

        // Change practice state — irrelevant to library
        changeCount = 0
        state.isPracticing = true
        let practiceChanges = changeCount

        // Change calendar state — irrelevant to library
        changeCount = 0
        state.isCalendarPresented = true
        let calendarChanges = changeCount

        print("🔄 objectWillChange counts: searchText=\(searchChanges), isPracticing=\(practiceChanges), isCalendarPresented=\(calendarChanges)")
        // All should be 1 — monolithic state means everything triggers everything
        XCTAssertEqual(searchChanges, 1)
        XCTAssertEqual(practiceChanges, 1)
        XCTAssertEqual(calendarChanges, 1)

        cancellable.cancel()
    }

    // MARK: - Test 5: filteredLibrary correctness

    func testFilteredLibraryCorrectness() {
        let state = TestHelpers.makePopulatedAppState(libraryCount: 100)

        // No filter — should return all
        let all = state.filteredLibrary
        XCTAssertEqual(all.count, 100)

        // Filter by type
        state.typeFilter = .song
        let songs = state.filteredLibrary
        XCTAssertTrue(songs.allSatisfy { $0.type == .song })

        // Filter by search text
        state.typeFilter = nil
        state.searchText = "Exercise"
        let exercises = state.filteredLibrary
        XCTAssertTrue(exercises.allSatisfy {
            $0.name.lowercased().contains("exercise") ||
            ($0.artist?.lowercased().contains("exercise") ?? false) ||
            $0.tags.contains { $0.lowercased().contains("exercise") }
        })

        // Sort by name ascending
        state.searchText = ""
        state.sortOption = .name
        state.sortAscending = true
        let sorted = state.filteredLibrary
        for i in 0..<(sorted.count - 1) {
            XCTAssertTrue(
                sorted[i].name.localizedCaseInsensitiveCompare(sorted[i+1].name) != .orderedDescending,
                "Items should be sorted ascending by name"
            )
        }
    }
}
