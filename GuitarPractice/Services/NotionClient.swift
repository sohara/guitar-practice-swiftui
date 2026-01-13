import Foundation

enum NotionError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Notion API key configured"
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from Notion"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message ?? "Unknown error")"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

actor NotionClient {
    private let apiKey: String
    private let baseURL = Config.Notion.baseURL
    private let apiVersion = Config.Notion.apiVersion

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Fetch Practice Library

    func fetchLibrary() async throws -> [LibraryItem] {
        var items: [LibraryItem] = []
        var cursor: String? = nil

        repeat {
            let (results, nextCursor) = try await queryDataSource(
                dataSourceId: Config.Notion.DataSources.practiceLibrary,
                cursor: cursor
            )

            for page in results {
                if let item = parseLibraryItem(from: page) {
                    items.append(item)
                }
            }

            cursor = nextCursor
        } while cursor != nil

        return items
    }

    // MARK: - Fetch Practice Sessions

    func fetchSessions() async throws -> [PracticeSession] {
        var sessions: [PracticeSession] = []
        var cursor: String? = nil

        repeat {
            let (results, nextCursor) = try await queryDataSource(
                dataSourceId: Config.Notion.DataSources.practiceSessions,
                cursor: cursor,
                sorts: [["property": "Date", "direction": "descending"]]
            )

            for page in results {
                if let session = parseSession(from: page) {
                    sessions.append(session)
                }
            }

            cursor = nextCursor
        } while cursor != nil

        return sessions
    }

    // MARK: - Fetch Practice Logs for Session

    func fetchLogs(forSession sessionId: String) async throws -> [PracticeLog] {
        var logs: [PracticeLog] = []
        var cursor: String? = nil

        repeat {
            let (results, nextCursor) = try await queryDataSource(
                dataSourceId: Config.Notion.DataSources.practiceLogs,
                cursor: cursor,
                filter: [
                    "property": "Session",
                    "relation": ["contains": sessionId]
                ],
                sorts: [["property": "Order", "direction": "ascending"]]
            )

            for page in results {
                if let log = parseLog(from: page) {
                    logs.append(log)
                }
            }

            cursor = nextCursor
        } while cursor != nil

        return logs
    }

    // MARK: - Create Practice Session

    func createSession(_ session: NewPracticeSession) async throws -> PracticeSession {
        let body: [String: Any] = [
            "parent": ["database_id": Config.Notion.Databases.practiceSessions],
            "properties": [
                "Session": ["title": [["text": ["content": session.name]]]],
                "Date": ["date": ["start": session.date]]
            ],
            "template": [
                "type": "template_id",
                "template_id": Config.Notion.Templates.practiceSession
            ]
        ]

        let data = try await postRequest(endpoint: "/pages", body: body)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw NotionError.invalidResponse
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: session.date) ?? Date()

        return PracticeSession(id: id, name: session.name, date: date)
    }

    // MARK: - Create Practice Log

    func createLog(_ log: NewPracticeLog) async throws -> String {
        let body: [String: Any] = [
            "parent": ["database_id": Config.Notion.Databases.practiceLogs],
            "properties": [
                "Name": ["title": [["text": ["content": log.name]]]],
                "Item": ["relation": [["id": log.itemId]]],
                "Session": ["relation": [["id": log.sessionId]]],
                "Planned Time (min)": ["number": log.plannedMinutes],
                "Order": ["number": log.order]
            ]
        ]

        let data = try await postRequest(endpoint: "/pages", body: body)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw NotionError.invalidResponse
        }

        return id
    }

    // MARK: - Update Practice Log

    func updateLog(
        logId: String,
        plannedMinutes: Int? = nil,
        actualMinutes: Double? = nil,
        order: Int? = nil
    ) async throws {
        var properties: [String: Any] = [:]

        if let planned = plannedMinutes {
            properties["Planned Time (min)"] = ["number": planned]
        }
        if let actual = actualMinutes {
            properties["Actual Time (min)"] = ["number": actual]
        }
        if let ord = order {
            properties["Order"] = ["number": ord]
        }

        let body: [String: Any] = ["properties": properties]
        _ = try await patchRequest(endpoint: "/pages/\(logId)", body: body)
    }

    // MARK: - Delete (Archive) Practice Log

    func deleteLog(logId: String) async throws {
        let body: [String: Any] = ["archived": true]
        _ = try await patchRequest(endpoint: "/pages/\(logId)", body: body)
    }

    // MARK: - Private Helpers

    private func queryDataSource(
        dataSourceId: String,
        cursor: String? = nil,
        filter: [String: Any]? = nil,
        sorts: [[String: String]]? = nil
    ) async throws -> (results: [[String: Any]], nextCursor: String?) {
        var body: [String: Any] = ["page_size": 100]
        if let cursor = cursor {
            body["start_cursor"] = cursor
        }
        if let filter = filter {
            body["filter"] = filter
        }
        if let sorts = sorts {
            body["sorts"] = sorts
        }

        let data = try await postRequest(
            endpoint: "/databases/\(dataSourceId)/query",
            body: body
        )

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw NotionError.invalidResponse
        }

        let hasMore = json["has_more"] as? Bool ?? false
        let nextCursor = hasMore ? json["next_cursor"] as? String : nil

        return (results, nextCursor)
    }

    private func postRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        return try await request(method: "POST", endpoint: endpoint, body: body)
    }

    private func patchRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        return try await request(method: "PATCH", endpoint: endpoint, body: body)
    }

    private func request(
        method: String,
        endpoint: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NotionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NotionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = message?["message"] as? String
            throw NotionError.httpError(httpResponse.statusCode, errorMessage)
        }

        return data
    }

    // MARK: - Parsing Helpers

    private func parseLibraryItem(from page: [String: Any]) -> LibraryItem? {
        guard let id = page["id"] as? String,
              let properties = page["properties"] as? [String: Any] else {
            return nil
        }

        let name = getTitle(properties["Name"])
        let type = getSelect(properties["Type"]).flatMap { ItemType(rawValue: $0) }
        let artist = getRichText(properties["Artist"])
        let tags = getMultiSelect(properties["Tags"])
        let lastPracticedStr = getFormula(properties["Last Practiced"])
        let timesPracticed = getRollup(properties["Times Practiced"]) ?? 0

        var lastPracticed: Date? = nil
        if let dateStr = lastPracticedStr {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            lastPracticed = formatter.date(from: dateStr)
        }

        return LibraryItem(
            id: id,
            name: name,
            type: type,
            artist: artist.isEmpty ? nil : artist,
            tags: tags,
            lastPracticed: lastPracticed,
            timesPracticed: timesPracticed
        )
    }

    private func parseSession(from page: [String: Any]) -> PracticeSession? {
        guard let id = page["id"] as? String,
              let properties = page["properties"] as? [String: Any] else {
            return nil
        }

        let name = getTitle(properties["Session"])
        let dateStr = getDate(properties["Date"]) ?? ""

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dateStr) ?? Date()

        return PracticeSession(id: id, name: name, date: date)
    }

    private func parseLog(from page: [String: Any]) -> PracticeLog? {
        guard let id = page["id"] as? String,
              let properties = page["properties"] as? [String: Any] else {
            return nil
        }

        let name = getTitle(properties["Name"])
        let itemIds = getRelation(properties["Item"])
        let sessionIds = getRelation(properties["Session"])
        let plannedTime = getNumber(properties["Planned Time (min)"]) ?? 5
        let actualTime = getNumber(properties["Actual Time (min)"])
        let order = getNumber(properties["Order"]) ?? 0

        return PracticeLog(
            id: id,
            name: name,
            itemId: itemIds.first ?? "",
            sessionId: sessionIds.first ?? "",
            plannedMinutes: Int(plannedTime),
            actualMinutes: actualTime,
            order: Int(order)
        )
    }

    // MARK: - Property Extractors

    private func getTitle(_ prop: Any?) -> String {
        guard let prop = prop as? [String: Any],
              let title = prop["title"] as? [[String: Any]] else {
            return ""
        }
        return title.compactMap { $0["plain_text"] as? String }.joined()
    }

    private func getRichText(_ prop: Any?) -> String {
        guard let prop = prop as? [String: Any],
              let richText = prop["rich_text"] as? [[String: Any]] else {
            return ""
        }
        return richText.compactMap { $0["plain_text"] as? String }.joined()
    }

    private func getSelect(_ prop: Any?) -> String? {
        guard let prop = prop as? [String: Any],
              let select = prop["select"] as? [String: Any],
              let name = select["name"] as? String else {
            return nil
        }
        return name
    }

    private func getMultiSelect(_ prop: Any?) -> [String] {
        guard let prop = prop as? [String: Any],
              let multiSelect = prop["multi_select"] as? [[String: Any]] else {
            return []
        }
        return multiSelect.compactMap { $0["name"] as? String }
    }

    private func getNumber(_ prop: Any?) -> Double? {
        guard let prop = prop as? [String: Any] else { return nil }
        return prop["number"] as? Double
    }

    private func getDate(_ prop: Any?) -> String? {
        guard let prop = prop as? [String: Any],
              let date = prop["date"] as? [String: Any],
              let start = date["start"] as? String else {
            return nil
        }
        return start
    }

    private func getFormula(_ prop: Any?) -> String? {
        guard let prop = prop as? [String: Any],
              let formula = prop["formula"] as? [String: Any] else {
            return nil
        }

        if let str = formula["string"] as? String { return str }
        if let date = formula["date"] as? [String: Any],
           let start = date["start"] as? String { return start }
        return nil
    }

    private func getRollup(_ prop: Any?) -> Int? {
        guard let prop = prop as? [String: Any],
              let rollup = prop["rollup"] as? [String: Any] else {
            return nil
        }

        if let num = rollup["number"] as? Double { return Int(num) }
        return nil
    }

    private func getRelation(_ prop: Any?) -> [String] {
        guard let prop = prop as? [String: Any],
              let relation = prop["relation"] as? [[String: Any]] else {
            return []
        }
        return relation.compactMap { $0["id"] as? String }
    }
}
