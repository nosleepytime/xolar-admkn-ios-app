import SwiftUI

struct ContentView: View {
    @StateObject private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if state.session == nil {
                LoginView()
                    .environmentObject(state)
            } else {
                DashboardView()
                    .environmentObject(state)
            }
        }
        .onAppear {
            NotificationManager.shared.clearAllDeliveredNotifications()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                NotificationManager.shared.clearAllDeliveredNotifications()
                state.startRealtime()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .xolarOpenTicketFromNotification)) { output in
            guard let ticketId = output.userInfo?["ticketId"] as? String else { return }

            state.openTicket(ticketId: ticketId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .xolarFCMTokenDidUpdate)) { output in
            guard let token = output.userInfo?["token"] as? String else { return }

            state.saveFCMToken(token)
        }
    }
}