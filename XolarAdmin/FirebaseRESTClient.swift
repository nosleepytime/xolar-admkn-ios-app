import Foundation

enum XolarAPIError: LocalizedError {
    case invalidConfig
    case invalidURL
    case invalidResponse
    case serverError(String)
    case loginFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfig:
            return "Firebase config is missing."
        case .invalidURL:
            return "Invalid Firebase URL."
        case .invalidResponse:
            return "Invalid server response."
        case .serverError(let message):
            return message
        case .loginFailed(let message):
            return message
        }
    }
}

final class FirebaseRESTClient {
    private let apiKey: String
    private let databaseURL: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        apiKey: String = AppConfig.firebaseApiKey,
        databaseURL: String = AppConfig.realtimeDatabaseURL
    ) {
        self.apiKey = apiKey
        self.databaseURL = databaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func signIn(email: String, password: String) async throws -> AdminSession {
        guard !apiKey.isEmpty else {
            throw XolarAPIError.invalidConfig
        }

        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)") else {
            throw XolarAPIError.invalidURL
        }

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let auth = try decoder.decode(FirebaseAuthResponse.self, from: data)
        let seconds = Double(auth.expiresIn) ?? 3600

        return AdminSession(
            uid: auth.localId,
            email: auth.email,
            idToken: auth.idToken,
            refreshToken: auth.refreshToken,
            expiresAt: Date().timeIntervalSince1970 + seconds
        )
    }

    func fetchTickets(session: AdminSession) async throws -> [Ticket] {
        let raw: [String: TicketPayload]? = try await dbGet(path: "tickets", session: session)
        return (raw ?? [:])
            .map { Ticket(id: $0.key, payload: $0.value) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchMessages(ticketId: String, session: AdminSession) async throws -> [TicketMessage] {
        let raw: [String: TicketMessagePayload]? = try await dbGet(path: "tickets/\(ticketId)/messages", session: session)
        return (raw ?? [:])
            .map { TicketMessage(id: $0.key, payload: $0.value) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchAgentNotifications(uid: String, session: AdminSession) async throws -> [AgentNotification] {
        let raw: [String: AgentNotificationPayload]? = try await dbGet(path: "agentNotifications/\(uid)", session: session)
        return (raw ?? [:])
            .map { AgentNotification(id: $0.key, payload: $0.value) }
            .filter { !$0.read }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchAgents(session: AdminSession) async throws -> [Agent] {
        let raw: [String: AgentPayload]? = try await dbGet(path: "agents", session: session)
        return (raw ?? [:])
            .map { Agent(id: $0.key, payload: $0.value) }
            .sorted { $0.username.lowercased() < $1.username.lowercased() }
    }

    func sendAgentMessage(ticketId: String, text: String, session: AdminSession) async throws {
        let now = Date().timeIntervalSince1970

        let message: [String: Any] = [
            "senderType": "agent",
            "senderName": session.email,
            "senderId": session.uid,
            "text": text,
            "createdAt": now
        ]

        _ = try await dbPost(path: "tickets/\(ticketId)/messages", json: message, session: session)

        try await dbPatch(path: "tickets/\(ticketId)", json: [
            "lastMessage": text,
            "updatedAt": now,
            "status": "open",
            "unreadForAgent": false
        ], session: session)
    }

    func joinTicket(ticketId: String, session: AdminSession) async throws {
        try await dbPatch(path: "tickets/\(ticketId)", json: [
            "assignedAgentId": session.uid,
            "assignedAgentEmail": session.email,
            "updatedAt": Date().timeIntervalSince1970
        ], session: session)
    }

    func closeTicket(ticketId: String, reason: String, session: AdminSession) async throws {
        try await dbPatch(path: "tickets/\(ticketId)", json: [
            "status": "closed",
            "closeReason": reason,
            "closedBy": session.email,
            "closedAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970
        ], session: session)
    }

    func transferTicket(ticketId: String, targetAgentId: String, targetAgentEmail: String, session: AdminSession) async throws {
        let now = Date().timeIntervalSince1970

        try await dbPatch(path: "tickets/\(ticketId)", json: [
            "assignedAgentId": targetAgentId,
            "assignedAgentEmail": targetAgentEmail,
            "updatedAt": now
        ], session: session)

        let notification: [String: Any] = [
            "type": "ticket_transfer",
            "title": "Ticket transferred to you",
            "body": "A ticket was assigned to you by \(session.email).",
            "ticketId": ticketId,
            "targetAgentId": targetAgentId,
            "createdAt": now,
            "read": false
        ]

        _ = try await dbPost(path: "agentNotifications/\(targetAgentId)", json: notification, session: session)
    }

    func markTicketRead(ticketId: String, session: AdminSession) async throws {
        try await dbPatch(path: "tickets/\(ticketId)", json: [
            "unreadForAgent": false
        ], session: session)
    }

    func deleteNotification(notificationId: String, uid: String, session: AdminSession) async throws {
        try await dbDelete(path: "agentNotifications/\(uid)/\(notificationId)", session: session)
    }

    private func dbURL(path: String, session: AdminSession) throws -> URL {
        guard !databaseURL.isEmpty else {
            throw XolarAPIError.invalidConfig
        }

        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(databaseURL)/\(cleanPath).json"

        guard var components = URLComponents(string: urlString) else {
            throw XolarAPIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "auth", value: session.idToken)
        ]

        guard let url = components.url else {
            throw XolarAPIError.invalidURL
        }

        return url
    }

    private func dbGet<T: Decodable>(path: String, session: AdminSession) async throws -> T {
        let url = try dbURL(path: path, session: session)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        return try decoder.decode(T.self, from: data)
    }

    private func dbPost(path: String, json: [String: Any], session: AdminSession) async throws -> FirebasePostResponse {
        let data = try await dbJSON(path: path, method: "POST", json: json, session: session)
        return try decoder.decode(FirebasePostResponse.self, from: data)
    }

    private func dbPatch(path: String, json: [String: Any], session: AdminSession) async throws {
        _ = try await dbJSON(path: path, method: "PATCH", json: json, session: session)
    }

    private func dbDelete(path: String, session: AdminSession) async throws {
        let url = try dbURL(path: path, session: session)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private func dbJSON(path: String, method: String, json: [String: Any], session: AdminSession) async throws -> Data {
        let url = try dbURL(path: path, session: session)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw XolarAPIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            if http.statusCode == 400 || http.statusCode == 401 || http.statusCode == 403 {
                throw XolarAPIError.loginFailed(message)
            }
            throw XolarAPIError.serverError(message)
        }
    }
}
