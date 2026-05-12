import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @State private var searchText = ""
    @State private var selectedFilter = "open"
    @State private var showNotifications = false
    @State private var showSettings = false

    private let filters = ["open", "closed", "all"]

    private var filteredTickets: [Ticket] {
        state.tickets.filter { ticket in
            let matchesFilter = selectedFilter == "all" || ticket.status.lowercased() == selectedFilter
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if query.isEmpty {
                return matchesFilter
            }

            return matchesFilter && (
                ticket.id.lowercased().contains(query) ||
                ticket.subject.lowercased().contains(query) ||
                ticket.customerName.lowercased().contains(query) ||
                ticket.lastMessage.lowercased().contains(query)
            )
        }
    }

    var body: some View {
        NavigationStack(path: $state.path) {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(filters, id: \.self) { filter in
                            Text(filter.capitalized).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    List {
                        ForEach(filteredTickets) { ticket in
                            Button {
                                state.openTicket(ticketId: ticket.id)
                            } label: {
                                TicketRowView(ticket: ticket)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await state.refreshAll()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search ticket, customer, message...")
            .navigationTitle("Xolar Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.green)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNotifications = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.title3)
                                .foregroundStyle(.green)

                            if !state.localNotifications.isEmpty {
                                Text("\(min(state.localNotifications.count, 99))")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.black)
                                    .padding(5)
                                    .background(.green)
                                    .clipShape(Circle())
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationInboxView(isPresented: $showNotifications)
                    .environmentObject(state)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(state)
            }
            .navigationDestination(for: String.self) { ticketId in
                TicketDetailView(ticketId: ticketId)
                    .environmentObject(state)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Support Center")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text(state.session?.email ?? "Admin")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Button {
                    Task {
                        await state.refreshAll()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                        .padding(12)
                        .background(.white.opacity(0.10))
                        .clipShape(Circle())
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 10) {
                StatCard(title: "Tickets", value: "\(state.tickets.count)", icon: "tray.full.fill")
                StatCard(title: "Unread", value: "\(state.localNotifications.count)", icon: "bell.badge.fill")
                StatCard(title: "Agents", value: "\(state.agents.count)", icon: "person.2.fill")
            }
        }
        .padding()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.green)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct TicketRowView: View {
    let ticket: Ticket

    private var statusColor: Color {
        ticket.status.lowercased() == "closed" ? .red : .green
    }

    private var priorityText: String {
        ticket.priority.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.subject)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(ticket.customerName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.60))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(ticket.status.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(statusColor)

                    Text(priorityText)
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            if !ticket.lastMessage.isEmpty {
                Text(ticket.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }

            HStack {
                if let assigned = ticket.assignedAgentEmail, !assigned.isEmpty {
                    Label(assigned, systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.85))
                } else {
                    Label("Unassigned", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text(ticket.updatedAt.xolarDateText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding()
        .background(ticket.unreadForAgent ? Color.green.opacity(0.14) : Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(ticket.unreadForAgent ? Color.green.opacity(0.45) : Color.white.opacity(0.08))
        )
    }
}
