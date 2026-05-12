import Foundation

struct AdminSession: Codable, Equatable {
    let uid: String
    let email: String
    let idToken: String
    let refreshToken: String
    let expiresAt: Double

    var isExpired: Bool {
        Date().timeIntervalSince1970 > expiresAt - 60
    }
}

struct FirebaseAuthResponse: Decodable {
    let idToken: String
    let email: String
    let refreshToken: String
    let expiresIn: String
    let localId: String
}

struct FirebasePostResponse: Decodable {
    let name: String
}

struct TicketPayload: Codable {
    var subject: String?
    var customerName: String?
    var customerTelegram: String?
    var assignedAgentId: String?
    var assignedAgentEmail: String?
    var status: String?
    var priority: String?
    var lastMessage: String?
    var updatedAt: Double?
    var createdAt: Double?
    var unreadForAgent: Bool?
}

struct Ticket: Identifiable, Hashable, Codable {
    let id: String
    var subject: String
    var customerName: String
    var customerTelegram: String
    var assignedAgentId: String?
    var assignedAgentEmail: String?
    var status: String
    var priority: String
    var lastMessage: String
    var updatedAt: Double
    var createdAt: Double
    var unreadForAgent: Bool

    init(id: String, payload: TicketPayload) {
        self.id = id
        self.subject = payload.subject ?? "Support Ticket"
        self.customerName = payload.customerName ?? "Customer"
        self.customerTelegram = payload.customerTelegram ?? ""
        self.assignedAgentId = payload.assignedAgentId
        self.assignedAgentEmail = payload.assignedAgentEmail
        self.status = payload.status ?? "open"
        self.priority = payload.priority ?? "normal"
        self.lastMessage = payload.lastMessage ?? ""
        self.updatedAt = payload.updatedAt ?? payload.createdAt ?? 0
        self.createdAt = payload.createdAt ?? 0
        self.unreadForAgent = payload.unreadForAgent ?? false
    }
}

struct TicketMessagePayload: Codable {
    var senderType: String?
    var senderName: String?
    var senderId: String?
    var text: String?
    var createdAt: Double?
}

struct TicketMessage: Identifiable, Hashable, Codable {
    let id: String
    var senderType: String
    var senderName: String
    var senderId: String
    var text: String
    var createdAt: Double

    init(id: String, payload: TicketMessagePayload) {
        self.id = id
        self.senderType = payload.senderType ?? "system"
        self.senderName = payload.senderName ?? "Unknown"
        self.senderId = payload.senderId ?? ""
        self.text = payload.text ?? ""
        self.createdAt = payload.createdAt ?? 0
    }
}

struct AgentNotificationPayload: Codable {
    var type: String?
    var title: String?
    var body: String?
    var ticketId: String?
    var targetAgentId: String?
    var createdAt: Double?
    var read: Bool?
}

struct AgentNotification: Identifiable, Hashable, Codable {
    let id: String
    var type: String
    var title: String
    var body: String
    var ticketId: String
    var targetAgentId: String
    var createdAt: Double
    var read: Bool

    init(id: String, payload: AgentNotificationPayload) {
        self.id = id
        self.type = payload.type ?? "general"
        self.title = payload.title ?? "Xolar Notification"
        self.body = payload.body ?? "New activity"
        self.ticketId = payload.ticketId ?? ""
        self.targetAgentId = payload.targetAgentId ?? ""
        self.createdAt = payload.createdAt ?? Date().timeIntervalSince1970
        self.read = payload.read ?? false
    }
}

struct AgentPayload: Codable {
    var email: String?
    var username: String?
    var online: Bool?
}

struct Agent: Identifiable, Hashable {
    let id: String
    var email: String
    var username: String
    var online: Bool

    init(id: String, payload: AgentPayload) {
        self.id = id
        self.email = payload.email ?? ""
        self.username = payload.username ?? "Agent"
        self.online = payload.online ?? false
    }
}

extension Double {
    var xolarDateText: String {
        guard self > 0 else { return "Unknown" }
        let date = Date(timeIntervalSince1970: self)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
