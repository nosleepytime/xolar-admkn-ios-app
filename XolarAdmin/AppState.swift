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

    private let client = FirebaseRESTClient()
    private var pollingTask: Task<Void, Never>?
    private let sessionKey = "xolar.admin.session"
    private let notificationsKey = "xolar.admin.local.notifications"

    init() {
        loadSession()
        loadLocalNotifications()
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let newSession = try await client.signIn(email: email, password: password)
            session = newSession
            saveSession(newSession)
            await NotificationManager.shared.requestPermission()
            startPolling()
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        pollingTask?.cancel()
        pollingTask = nil
        session = nil
        tickets = []
        agents = []
        messages = [:]
        localNotifications = []
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.removeObject(forKey: notificationsKey)
        NotificationManager.shared.clearAllDeliveredNotifications()
    }

    func startPolling() {
        guard pollingTask == nil else { return }
        guard session != nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAll()
                try? await Task.sleep(nanoseconds: AppConfig.pollNanoseconds)
            }
        }
    }

    func refreshAll() async {
        guard let session else { return }

        do {
            let newTickets = try await client.fetchTickets(session: session)
            let newAgents = try await client.fetchAgents(session: session)
            let remoteNotifications = try await client.fetchAgentNotifications(uid: session.uid, session: session)

            tickets = newTickets
            agents = newAgents

            for notification in remoteNotifications {
                let inserted = addLocalNotificationIfNeeded(notification)
                if inserted {
                    NotificationManager.shared.sendLocalNotification(notification)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMessages(ticketId: String) async {
        guard let session else { return }

        do {
            let newMessages = try await client.fetchMessages(ticketId: ticketId, session: session)
            messages[ticketId] = newMessages
            try? await client.markTicketRead(ticketId: ticketId, session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendReply(ticketId: String, text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard let session else { return }

        do {
            try await client.sendAgentMessage(ticketId: ticketId, text: clean, session: session)
            await loadMessages(ticketId: ticketId)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinTicket(ticketId: String) async {
        guard let session else { return }

        do {
            try await client.joinTicket(ticketId: ticketId, session: session)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeTicket(ticketId: String, reason: String) async {
        guard let session else { return }

        do {
            try await client.closeTicket(ticketId: ticketId, reason: reason, session: session)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transferTicket(ticketId: String, targetAgentId: String, targetAgentEmail: String) async {
        guard let session else { return }

        do {
            try await client.transferTicket(
                ticketId: ticketId,
                targetAgentId: targetAgentId,
                targetAgentEmail: targetAgentEmail,
                session: session
            )
            await refreshAll()
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
            await markNotificationsForTicketAsRead(ticketId: ticketId)
            await loadMessages(ticketId: ticketId)
        }
    }

    func markNotificationAsRead(_ notification: AgentNotification) async {
        removeLocalNotification(id: notification.id)
        NotificationManager.shared.clearDeliveredNotification(id: notification.id)

        guard let session else { return }

        do {
            try await client.deleteNotification(
                notificationId: notification.id,
                uid: session.uid,
                session: session
            )
        } catch {
            errorMessage = error.localizedDescription
        }
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

    private func saveSession(_ session: AdminSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return }
        guard let saved = try? JSONDecoder().decode(AdminSession.self, from: data) else { return }

        if saved.isExpired {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        } else {
            session = saved
            startPolling()
        }
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
