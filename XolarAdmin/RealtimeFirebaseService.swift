import Foundation
import FirebaseAuth
import FirebaseDatabase

final class RealtimeFirebaseService {
    private var ticketsHandle: DatabaseHandle?
    private var agentsHandle: DatabaseHandle?
    private var notificationsHandle: DatabaseHandle?
    private var appMessagesHandle: DatabaseHandle?
    private var legacyMessagesHandle: DatabaseHandle?

    private var activeTicketId: String?
    private var latestAppMessages: [TicketMessage] = []
    private var latestLegacyMessages: [TicketMessage] = []

    private var db: DatabaseReference {
        Database.database().reference()
    }

    func currentSession() async throws -> AdminSession? {
        guard let user = Auth.auth().currentUser else {
            return nil
        }

        let token = try await user.getIDTokenForcingRefresh(false)

        return AdminSession(
            uid: user.uid,
            email: user.email ?? "",
            idToken: token,
            refreshToken: "",
            expiresAt: Date().timeIntervalSince1970 + 3600
        )
    }

    func signIn(email: String, password: String) async throws -> AdminSession {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        let user = result.user
        let token = try await user.getIDTokenForcingRefresh(true)

        return AdminSession(
            uid: user.uid,
            email: user.email ?? email,
            idToken: token,
            refreshToken: "",
            expiresAt: Date().timeIntervalSince1970 + 3600
        )
    }

    func signOut() throws {
        try Auth.auth().signOut()
        detachAll()
    }

    func observeTickets(onChange: @escaping ([Ticket]) -> Void) {
        if let handle = ticketsHandle {
            db.child("tickets").removeObserver(withHandle: handle)
        }

        ticketsHandle = db.child("tickets").observe(.value) { snapshot in
            var tickets: [Ticket] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }
                guard let payload = RealtimeFirebaseService.decodeSnapshot(childSnapshot, as: TicketPayload.self) else { continue }

                tickets.append(Ticket(id: childSnapshot.key, payload: payload))
            }

            tickets.sort {
                $0.updatedAt.normalizedTimestamp > $1.updatedAt.normalizedTimestamp
            }

            DispatchQueue.main.async {
                onChange(tickets)
            }
        }
    }

    func observeAgents(onChange: @escaping ([Agent]) -> Void) {
        if let handle = agentsHandle {
            db.child("agents").removeObserver(withHandle: handle)
        }

        agentsHandle = db.child("agents").observe(.value) { snapshot in
            var agents: [Agent] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }
                guard let payload = RealtimeFirebaseService.decodeSnapshot(childSnapshot, as: AgentPayload.self) else { continue }
                guard payload.enabled != false else { continue }

                agents.append(Agent(id: childSnapshot.key, payload: payload))
            }

            agents.sort {
                $0.username.lowercased() < $1.username.lowercased()
            }

            DispatchQueue.main.async {
                onChange(agents)
            }
        }
    }

    func observeNotifications(uid: String, onChange: @escaping ([AgentNotification]) -> Void) {
        if let handle = notificationsHandle {
            db.child("agentNotifications").child(uid).removeObserver(withHandle: handle)
        }

        notificationsHandle = db.child("agentNotifications").child(uid).observe(.value) { snapshot in
            var notifications: [AgentNotification] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }
                guard let payload = RealtimeFirebaseService.decodeSnapshot(childSnapshot, as: AgentNotificationPayload.self) else { continue }
                guard payload.read != true else { continue }
                guard !(payload.ticketId ?? "").isEmpty else { continue }

                notifications.append(AgentNotification(id: childSnapshot.key, payload: payload))
            }

            notifications.sort {
                $0.createdAt.normalizedTimestamp > $1.createdAt.normalizedTimestamp
            }

            DispatchQueue.main.async {
                onChange(notifications)
            }
        }
    }

    func observeMessages(ticketId: String, onChange: @escaping ([TicketMessage]) -> Void) {
        detachMessages()

        activeTicketId = ticketId
        latestAppMessages = []
        latestLegacyMessages = []

        appMessagesHandle = db.child("tickets").child(ticketId).child("messages").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }

            var messages: [TicketMessage] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }
                guard let payload = RealtimeFirebaseService.decodeSnapshot(childSnapshot, as: TicketMessagePayload.self) else { continue }

                messages.append(TicketMessage(id: childSnapshot.key, payload: payload))
            }

            self.latestAppMessages = messages
            let combined = self.combinedMessages()

            DispatchQueue.main.async {
                onChange(combined)
            }
        }

        legacyMessagesHandle = db.child("ticketMessages").child(ticketId).observe(.value) { [weak self] snapshot in
            guard let self = self else { return }

            var messages: [TicketMessage] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }
                guard let payload = RealtimeFirebaseService.decodeSnapshot(childSnapshot, as: LegacyTicketMessagePayload.self) else { continue }

                messages.append(TicketMessage(id: childSnapshot.key, legacy: payload))
            }

            self.latestLegacyMessages = messages
            let combined = self.combinedMessages()

            DispatchQueue.main.async {
                onChange(combined)
            }
        }
    }

    func detachMessages() {
        guard let ticketId = activeTicketId else { return }

        if let handle = appMessagesHandle {
            db.child("tickets").child(ticketId).child("messages").removeObserver(withHandle: handle)
        }

        if let handle = legacyMessagesHandle {
            db.child("ticketMessages").child(ticketId).removeObserver(withHandle: handle)
        }

        activeTicketId = nil
        appMessagesHandle = nil
        legacyMessagesHandle = nil
        latestAppMessages = []
        latestLegacyMessages = []
    }

    func markNotificationRead(uid: String, notificationId: String) {
        db.child("agentNotifications").child(uid).child(notificationId).removeValue()
    }

    func saveFCMToken(uid: String, token: String) {
        let key = RealtimeFirebaseService.safeFirebaseKey(token)

        db.child("agents")
            .child(uid)
            .child("fcmTokens")
            .child(key)
            .setValue([
                "token": token,
                "platform": "ios",
                "updatedAt": ServerValue.timestamp()
            ])
    }

    func detachAll() {
        if let handle = ticketsHandle {
            db.child("tickets").removeObserver(withHandle: handle)
        }

        if let handle = agentsHandle {
            db.child("agents").removeObserver(withHandle: handle)
        }

        if let uid = Auth.auth().currentUser?.uid, let handle = notificationsHandle {
            db.child("agentNotifications").child(uid).removeObserver(withHandle: handle)
        }

        detachMessages()

        ticketsHandle = nil
        agentsHandle = nil
        notificationsHandle = nil
    }

    private func combinedMessages() -> [TicketMessage] {
        var all = latestAppMessages
        var used = Set(all.map { $0.dedupeKey })

        for message in latestLegacyMessages {
            if !used.contains(message.dedupeKey) {
                all.append(message)
                used.insert(message.dedupeKey)
            }
        }

        return all.sorted {
            $0.normalizedTime < $1.normalizedTime
        }
    }

    private static func decodeSnapshot<T: Decodable>(_ snapshot: DataSnapshot, as type: T.Type) -> T? {
        guard snapshot.exists(), !(snapshot.value is NSNull) else {
            return nil
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: snapshot.value as Any)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private static func safeFirebaseKey(_ token: String) -> String {
        let data = Data(token.utf8)

        return data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}