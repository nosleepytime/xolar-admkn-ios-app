import SwiftUI

struct NotificationInboxView: View {
    @EnvironmentObject private var state: AppState
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if state.localNotifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("No missed notifications")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Everything is clean. Read notifications are automatically deleted.")
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(state.localNotifications) { notification in
                            Button {
                                Task {
                                    await state.markNotificationAsRead(notification)
                                    state.openTicket(ticketId: notification.ticketId)
                                    isPresented = false
                                }
                            } label: {
                                NotificationRowView(notification: notification)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundStyle(.green)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        Task {
                            await state.clearAllLocalNotifications()
                        }
                    }
                    .foregroundStyle(.red)
                    .disabled(state.localNotifications.isEmpty)
                }
            }
        }
    }
}

struct NotificationRowView: View {
    let notification: AgentNotification

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)

                HStack {
                    Text(notification.type.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.green)

                    Spacer()

                    Text(notification.createdAt.xolarDateText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
        }
        .padding()
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var icon: String {
        switch notification.type {
        case "new_ticket":
            return "tray.and.arrow.down.fill"
        case "new_customer_message":
            return "message.badge.filled.fill"
        case "ticket_transfer":
            return "arrowshape.turn.up.right.fill"
        case "ticket_closed":
            return "checkmark.seal.fill"
        default:
            return "bell.fill"
        }
    }
}
