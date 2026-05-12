import SwiftUI

struct TicketDetailView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    let ticketId: String

    @State private var replyText = ""
    @State private var showCloseAlert = false
    @State private var closeReason = ""
    @State private var showTransferSheet = false
    @State private var targetAgentId = ""
    @State private var targetAgentEmail = ""

    private var ticket: Ticket? {
        state.tickets.first { $0.id == ticketId }
    }

    private var ticketMessages: [TicketMessage] {
        state.messages[ticketId] ?? []
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ticketHeader

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(ticketMessages) { message in
                            MessageBubbleView(message: message)
                        }
                    }
                    .padding()
                }

                composer
            }
        }
        .navigationTitle(ticket?.customerName ?? "Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Join Ticket") {
                        Task {
                            await state.joinTicket(ticketId: ticketId)
                        }
                    }

                    Button("Transfer Ticket") {
                        showTransferSheet = true
                    }

                    Button("Close Ticket", role: .destructive) {
                        showCloseAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .task {
            await state.markNotificationsForTicketAsRead(ticketId: ticketId)
            await state.loadMessages(ticketId: ticketId)
        }
        .alert("Close Ticket", isPresented: $showCloseAlert) {
            TextField("Reason", text: $closeReason)

            Button("Cancel", role: .cancel) {}

            Button("Close", role: .destructive) {
                Task {
                    await state.closeTicket(ticketId: ticketId, reason: closeReason.isEmpty ? "Closed by agent" : closeReason)
                }
            }
        } message: {
            Text("This will mark the ticket as closed.")
        }
        .sheet(isPresented: $showTransferSheet) {
            transferSheet
        }
    }

    private var ticketHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(ticket?.subject ?? "Support Ticket")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text("ID: \(ticketId)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Text((ticket?.status ?? "open").uppercased())
                    .font(.caption.bold())
                    .foregroundStyle((ticket?.status ?? "open") == "closed" ? .red : .green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            HStack {
                Label(ticket?.customerTelegram ?? "No Telegram", systemImage: "paperplane.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()

                if let assigned = ticket?.assignedAgentEmail, !assigned.isEmpty {
                    Label(assigned, systemImage: "person.fill.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Unassigned", systemImage: "person.fill.questionmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(.white.opacity(0.07))
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Reply to customer...", text: $replyText, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)

            Button {
                let text = replyText
                replyText = ""

                Task {
                    await state.sendReply(ticketId: ticketId, text: text)
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline)
                    .padding(13)
                    .background(.green)
                    .foregroundStyle(.black)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(.black)
    }

    private var transferSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Transfer this ticket to a specific agent.")
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)

                    TextField("Target Agent UID", text: $targetAgentId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)

                    TextField("Target Agent Email", text: $targetAgentEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)

                    if !state.agents.isEmpty {
                        List {
                            ForEach(state.agents) { agent in
                                Button {
                                    targetAgentId = agent.id
                                    targetAgentEmail = agent.email
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(agent.username)
                                                .foregroundStyle(.white)
                                            Text(agent.email)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.55))
                                        }

                                        Spacer()

                                        Circle()
                                            .fill(agent.online ? Color.green : Color.gray)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    Button {
                        Task {
                            await state.transferTicket(
                                ticketId: ticketId,
                                targetAgentId: targetAgentId,
                                targetAgentEmail: targetAgentEmail
                            )
                            showTransferSheet = false
                        }
                    } label: {
                        Text("Transfer Ticket")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(targetAgentId.isEmpty || targetAgentEmail.isEmpty)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MessageBubbleView: View {
    let message: TicketMessage

    private var isAgent: Bool {
        message.senderType.lowercased() == "agent"
    }

    var body: some View {
        HStack {
            if isAgent {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(message.senderName)
                        .font(.caption.bold())
                        .foregroundStyle(isAgent ? .black.opacity(0.7) : .white.opacity(0.65))

                    Spacer()

                    Text(message.createdAt.xolarDateText)
                        .font(.caption2)
                        .foregroundStyle(isAgent ? .black.opacity(0.45) : .white.opacity(0.35))
                }

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isAgent ? .black : .white)
            }
            .padding()
            .background(isAgent ? Color.green : Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if !isAgent {
                Spacer(minLength: 40)
            }
        }
    }
}
