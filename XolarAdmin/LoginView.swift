import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var state: AppState
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color.green.opacity(0.22), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 70))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Xolar Admin")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Manage support tickets, agents, transfers and notifications.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    TextField("Admin email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(.white)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(.white)

                    if let error = state.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await state.login(email: email, password: password)
                        }
                    } label: {
                        HStack {
                            if state.isLoading {
                                ProgressView()
                                    .tint(.black)
                            }

                            Text(state.isLoading ? "Signing in..." : "Sign In")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .disabled(state.isLoading)
                }
                .padding()
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(.white.opacity(0.12))
                )

                Spacer()

                Text("XOLAR SUPPORT CONTROL CENTER")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 10)
            }
            .padding()
        }
    }
}
