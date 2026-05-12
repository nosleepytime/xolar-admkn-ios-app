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
    var id: String?
    var title: String?
    var subject: String?
    var category: String?

    var customerName: String?
    var customerTelegram: String?

    var userId: String?
    var user: TicketUserPayload?

    var joinedBy: String?
    var joinedByName: String?

    var assignedAgentId: String?
    var assignedAgentEmail: String?

    var status: String?
    var priority: String?

    var lastMessage: String?
    var lastCustomerMessage: String?
    var lastAgentMessage: String?

    var updatedAt: Double?
    var createdAt: Double?

    var unreadForAgent: Bool?
    var customerUnreadCount: Int?
}

struct TicketUserPayload: Codable {
    var id: Int?
    var name: String?
    var username: String?
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

        let categoryName = payload.category?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        self.subject = payload.subject
            ?? payload.title
            ?? categoryName
            ?? "Support Ticket"

        self.customerName = payload.customerName
            ?? payload.user?.name
            ?? "Customer"

        if let telegram = payload.customerTelegram, !telegram.isEmpty {
            self.customerTelegram = telegram
        } else if let username = payload.user?.username, !username.isEmpty {
            self.customerTelegram = "@\(username)"
        } else if let userId = payload.userId {
            self.customerTelegram = userId
        } else {
            self.customerTelegram = ""
        }

        self.assignedAgentId = payload.assignedAgentId ?? payload.joinedBy
        self.assignedAgentEmail = payload.assignedAgentEmail ?? payload.joinedByName

        self.status = payload.status ?? "open"
        self.priority = payload.priority ?? "normal"

        self.lastMessage = payload.lastMessage
            ?? payload.lastCustomerMessage
            ?? payload.lastAgentMessage
            ?? ""

        self.updatedAt = payload.updatedAt ?? payload.createdAt ?? 0
        self.createdAt = payload.createdAt ?? 0
        self.unreadForAgent = payload.unreadForAgent ?? ((payload.customerUnreadCount ?? 0) > 0)
    }
}

struct TicketMessagePayload: Codable {
    var senderType: String?
    var senderName: String?
    var senderId: String?
    var text: String?
    var createdAt: Double?
}

struct LegacyTicketMessagePayload: Codable {
    var from: String?
    var text: String?
    var agentUid: String?
    var agentName: String?
    var createdAt: Double?
    var deleted: Bool?
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

    init(id: String, legacy: LegacyTicketMessagePayload) {
        self.id = id
        self.senderType = legacy.from ?? "system"

        if legacy.from == "agent" {
            self.senderName = legacy.agentName ?? "Agent"
            self.senderId = legacy.agentUid ?? ""
        } else if legacy.from == "customer" {
            self.senderName = "Customer"
            self.senderId = "customer"
        } else {
            self.senderName = "Xolar Support"
            self.senderId = "system"
        }

        self.text = legacy.deleted == true ? "[deleted]" : (legacy.text ?? "")
        self.createdAt = legacy.createdAt ?? 0
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
    var displayName: String?
    var online: Bool?
    var enabled: Bool?
}

struct Agent: Identifiable, Hashable {
    let id: String
    var email: String
    var username: String
    var online: Bool

    init(id: String, payload: AgentPayload) {
        self.id = id
        self.email = payload.email ?? ""
        self.username = payload.username ?? payload.displayName ?? "Agent"
        self.online = payload.online ?? false
    }
}

extension Double {
    var xolarDateText: String {
        guard self > 0 else { return "Unknown" }

        let timestamp = self > 9_999_999_999 ? self / 1000 : self
        let date = Date(timeIntervalSince1970: timestamp)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter.string(from: date)
    }
}