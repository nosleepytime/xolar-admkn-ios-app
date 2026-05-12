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
            return "Invalid URL."
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
    private let backendURL: String

    init(backendURL: String = AppConfig.supportBackendURL) {
        self.backendURL = backendURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func sendAgentMessage(ticketId: String, text: String, idToken: String) async throws {
        try await adminAction(
            idToken: idToken,
            body: [
                "action": "sendMessage",
                "ticketId": ticketId,
                "text": text,
                "type": "text"
            ]
        )
    }

    func joinTicket(ticketId: String, idToken: String) async throws {
        try await adminAction(
            idToken: idToken,
            body: [
                "action": "join",
                "ticketId": ticketId
            ]
        )
    }

    func closeTicket(ticketId: String, reason: String, idToken: String) async throws {
        try await adminAction(
            idToken: idToken,
            body: [
                "action": "close",
                "ticketId": ticketId,
                "reason": reason
            ]
        )
    }

    func transferTicket(ticketId: String, targetAgentId: String, idToken: String) async throws {
        try await adminAction(
            idToken: idToken,
            body: [
                "action": "transfer",
                "ticketId": ticketId,
                "targetUid": targetAgentId
            ]
        )
    }

    func markTicketRead(ticketId: String, idToken: String) async throws {
        try await adminAction(
            idToken: idToken,
            body: [
                "action": "read",
                "ticketId": ticketId
            ]
        )
    }

    private func adminAction(idToken: String, body: [String: Any]) async throws {
        guard !backendURL.isEmpty else {
            throw XolarAPIError.invalidConfig
        }

        guard let url = URL(string: "\(backendURL)/api/admin") else {
            throw XolarAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
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
