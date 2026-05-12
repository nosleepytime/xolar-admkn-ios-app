import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var session: AdminSession?
    @Published var tickets: [Ticket] = []
    @Published var agents: [Agent] = []
    @Published var messages: [String: [TicketMessage]] = [:]
    @Published var localNotifications: [AgentNotification] = []
    @Published var path: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let realtime = RealtimeFirebaseService()
    private let backend = FirebaseRESTClient()
    private let notificationsKey = "xolar.admin.local.notifications"

    init() {
        loadLocalNotifications()

        Task {
            await restoreSession()
        }
    }

    func restoreSession() async {
        do {
            if let restored = try await realtime.currentSession() {
                session = restored
                await NotificationManager.shared.requestPermission()
                startRealtime()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let newSession = try await realtime.signIn(email: email, password: password)
            session = newSession

            await NotificationManager.shared.requestPermission()
            startRealtime()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        do {
            try realtime.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }

        session = nil
        tickets = []
        agents = []
        messages = [:]
        localNotifications = []

        UserDefaults.standard.removeObject(forKey: notificationsKey)
        NotificationManager.shared.clearAllDeliveredNotifications()
    }

    func startPolling() {
        startRealtime()
    }

    func startRealtime() {
        guard let session else { return }

        realtime.observeTickets { [weak self] tickets in
            self?.tickets = tickets
        }

        realtime.observeAgents { [weak self] agents in
            self?.agents = agents
        }

        realtime.observeNotifications(uid: session.uid) { [weak self] notifications in
            guard let self else { return }

            for notification in notifications {
                let inserted = self.addLocalNotificationIfNeeded(notification)

                if inserted {
                    NotificationManager.shared.sendLocalNotification(notification)
                }
            }
        }
    }

    func refreshAll() async {
        startRealtime()
    }

    func activateTicket(ticketId: String) async {
        guard !ticketId.isEmpty else { return }

        realtime.observeMessages(ticketId: ticketId) { [weak self] newMessages in
            self?.messages[ticketId] = newMessages
        }

        await markNotificationsForTicketAsRead(ticketId: ticketId)

        do {
            let fresh = try await freshSession()
            try await backend.markTicketRead(ticketId: ticketId, idToken: fresh.idToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopActiveTicketRealtime() {
        realtime.detachMessages()
    }

    func loadMessages(ticketId: String) async {
        await activateTicket(ticketId: ticketId)
    }

    func sendReply(ticketId: String, text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        do {
            let fresh = try await freshSession()
            try await backend.sendAgentMessage(ticketId: ticketId, text: clean, idToken: fresh.idToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinTicket(ticketId: String) async {
        do {
            let fresh = try await freshSession()
            try await backend.joinTicket(ticketId: ticketId, idToken: fresh.idToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeTicket(ticketId: String, reason: String) async {
        do {
            let fresh = try await freshSession()
            try await backend.closeTicket(ticketId: ticketId, reason: reason, idToken: fresh.idToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transferTicket(ticketId: String, targetAgentId: String, targetAgentEmail: String) async {
        do {
            let fresh = try await freshSession()
            try await backend.transferTicket(ticketId: ticketId, targetAgentId: targetAgentId, idToken: fresh.idToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openTicket(ticketId: String) {
        guard !ticketId.isEmpty else { return }

        if path.last != ticketId {
            path.append(ticketId)
        }

        Task {
            await activateTicket(ticketId: ticketId)
        }
    }

    func markNotificationAsRead(_ notification: AgentNotification) async {
        removeLocalNotification(id: notification.id)
        NotificationManager.shared.clearDeliveredNotification(id: notification.id)

        guard let session else { return }

        realtime.markNotificationRead(uid: session.uid, notificationId: notification.id)
    }

    func markNotificationsForTicketAsRead(ticketId: String) async {
        let related = localNotifications.filter { $0.ticketId == ticketId }

        for notification in related {
            await markNotificationAsRead(notification)
        }
    }

    func clearAllLocalNotifications() async {
        let all = localNotifications

        for notification in all {
            await markNotificationAsRead(notification)
        }

        NotificationManager.shared.clearAllDeliveredNotifications()
    }

    func saveFCMToken(_ token: String) {
        guard let session else { return }

        realtime.saveFCMToken(uid: session.uid, token: token)
    }

    private func freshSession() async throws -> AdminSession {
        guard let fresh = try await realtime.currentSession() else {
            throw XolarAPIError.loginFailed("Session expired. Please sign in again.")
        }

        session = fresh
        return fresh
    }

    private func addLocalNotificationIfNeeded(_ notification: AgentNotification) -> Bool {
        guard !notification.ticketId.isEmpty else { return false }
        guard !localNotifications.contains(where: { $0.id == notification.id }) else { return false }

        localNotifications.insert(notification, at: 0)

        if localNotifications.count > AppConfig.maxLocalNotifications {
            localNotifications = Array(localNotifications.prefix(AppConfig.maxLocalNotifications))
        }

        saveLocalNotifications()
        return true
    }

    private func removeLocalNotification(id: String) {
        localNotifications.removeAll { $0.id == id }
        saveLocalNotifications()
    }

    private func saveLocalNotifications() {
        if let data = try? JSONEncoder().encode(localNotifications) {
            UserDefaults.standard.set(data, forKey: notificationsKey)
        }
    }

    private func loadLocalNotifications() {
        guard let data = UserDefaults.standard.data(forKey: notificationsKey) else { return }
        guard let saved = try? JSONDecoder().decode([AgentNotification].self, from: data) else { return }

        localNotifications = saved
    }
}
