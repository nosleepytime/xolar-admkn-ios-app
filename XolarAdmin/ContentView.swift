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
            state.startPolling()
            NotificationManager.shared.clearAllDeliveredNotifications()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                NotificationManager.shared.clearAllDeliveredNotifications()
                Task {
                    await state.refreshAll()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .xolarOpenTicketFromNotification)) { output in
            guard let ticketId = output.userInfo?["ticketId"] as? String else { return }
            state.openTicket(ticketId: ticketId)
        }
    }
}
