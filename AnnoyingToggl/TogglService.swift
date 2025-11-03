import Foundation

struct TogglService {
    private let baseURL = "https://api.track.toggl.com/api/v9"
    private let apiToken: String
    var onApiCall: (() -> Void)?

    init(apiToken: String) {
        self.apiToken = apiToken
    }

    private func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let credentials = "\(apiToken):api_token"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        return request
    }

    func getCurrentTimeEntry() async throws -> TimeEntry? {
        onApiCall?()
        print("API: Getting current time entry")
        let url = URL(string: "\(baseURL)/me/time_entries/current")!
        let request = createRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        print("API: Received data: \(String(data: data, encoding: .utf8) ?? "invalid")")
        if data == "null".data(using: .utf8) {
            print("API: No current timer")
            return nil
        } else {
            let entry = try JSONDecoder().decode(TimeEntry.self, from: data)
            print("API: Current timer: \(entry.description)")
            return entry
        }
    }

    func getWorkspaces() async throws -> [Workspace] {
        onApiCall?()
        print("API: Getting workspaces")
        let url = URL(string: "\(baseURL)/workspaces")!
        let request = createRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        let workspaces = try JSONDecoder().decode([Workspace].self, from: data)
        print("API: Workspaces: \(workspaces.map { $0.name })")
        return workspaces
    }

    func startTimeEntry(description: String, workspaceId: Int) async throws -> TimeEntry {
        onApiCall?()
        print("API: Starting time entry: \(description)")
        let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/time_entries")!
        var request = createRequest(url: url, method: "POST")
        let body: [String: Any] = [
            "description": description,
            "created_with": "AnnoyingToggl",
            "workspace_id": workspaceId,
            "duration": -1,
            "start": ISO8601DateFormatter().string(from: Date()),
            "stop": NSNull()
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let entry = try JSONDecoder().decode(TimeEntry.self, from: data)
        print("API: Started entry: \(entry.description)")
        return entry
    }

    func stopTimeEntry(timeEntryId: Int, workspaceId: Int) async throws -> TimeEntry {
        onApiCall?()
        let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/time_entries/\(timeEntryId)/stop")!
        let request = createRequest(url: url, method: "PATCH")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TimeEntry.self, from: data)
    }

    func updateTimeEntry(timeEntryId: Int, workspaceId: Int, description: String) async throws -> TimeEntry {
        onApiCall?()
        let url = URL(string: "\(baseURL)/workspaces/\(workspaceId)/time_entries/\(timeEntryId)")!
        var request = createRequest(url: url, method: "PUT")
        let body: [String: Any] = ["description": description]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TimeEntry.self, from: data)
    }

    func getRecentTimeEntries() async throws -> [TimeEntry] {
        onApiCall?()
        print("API: Getting recent time entries")
        let url = URL(string: "\(baseURL)/me/time_entries")!
        let request = createRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        let entries = try JSONDecoder().decode([TimeEntry].self, from: data)
        print("API: Recent entries count: \(entries.count)")
        return entries
    }
}

// Models
struct TimeEntry: Codable {
    let id: Int
    let wid: Int
    let pid: Int?
    let billable: Bool
    let start: String
    let duration: Int
    let description: String
    let at: String
}

struct Workspace: Codable {
    let id: Int
    let name: String
}