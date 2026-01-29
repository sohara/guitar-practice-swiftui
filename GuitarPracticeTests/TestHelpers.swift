import Foundation
@testable import GuitarPractice

enum TestHelpers {
    static func makeMockLibraryItems(count: Int) -> [LibraryItem] {
        let types: [ItemType] = [.song, .exercise, .courseLesson]
        let artists = ["Artist A", "Artist B", "Artist C", nil]
        let tagSets: [[String]] = [
            ["blues", "fingerpicking"],
            ["exercise", "technique"],
            ["course", "beginner"],
            ["jazz", "chords"],
        ]

        return (0..<count).map { i in
            LibraryItem(
                id: "item-\(i)",
                name: "Item \(i) \(types[i % types.count].rawValue)",
                type: types[i % types.count],
                artist: artists[i % artists.count],
                tags: tagSets[i % tagSets.count],
                lastPracticed: Calendar.current.date(byAdding: .day, value: -(i % 14), to: Date()),
                timesPracticed: i % 50
            )
        }
    }

    static func makeMockSessions(count: Int, baseDate: Date = Date()) -> [PracticeSession] {
        (0..<count).map { i in
            let date = Calendar.current.date(byAdding: .day, value: -i, to: baseDate)!
            return PracticeSession(
                id: "session-\(i)",
                name: "Session \(i)",
                date: date,
                goalMinutes: 30
            )
        }
    }

    @MainActor
    static func makePopulatedAppState(libraryCount: Int = 500) -> AppState {
        let state = AppState()
        let items = makeMockLibraryItems(count: libraryCount)
        state.libraryState = .loaded(items)
        return state
    }
}
