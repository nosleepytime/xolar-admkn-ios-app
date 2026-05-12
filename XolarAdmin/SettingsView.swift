import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 18) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 55))
                        .foregroundStyle(.green)
                        .padding(.top)

                    VStack(alignment: .leading, spacing: 14) {
                        settingRow(title: "Signed in as", value: state.session?.email ?? "Unknown")
                        settingRow(title: "Firebase URL", value: AppConfig.realtimeDatabaseURL)
                        settingRow(title: "Local Notifications", value: "\(state.localNotifications.count)")
                        settingRow(title: "Tickets Loaded", value: "\(state.tickets.count)")
                    }
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    Button {
                        NotificationManager.shared.clearAllDeliveredNotifications()
                    } label: {
                        Text("Clear iOS Notification Center")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.white.opacity(0.10))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Button(role: .destructive) {
                        state.logout()
                        dismiss()
                    } label: {
                        Text("Logout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.green)
                }
            }
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.green)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
