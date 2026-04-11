import SwiftUI

struct SetupView: View {
    @Environment(AppState.self) private var appState

    @State private var server   = "mgg-horb.webuntis.com"
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Server") {
                        TextField("school.webuntis.com", text: $server)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Username") {
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Password") {
                        SecureField("password", text: $password)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Your credentials are stored securely in the Keychain and never leave your device.")
                }

                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                            }
                            Text(isLoading ? "Signing in…" : "Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(server.isEmpty || username.isEmpty || password.isEmpty || isLoading)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign In to Untis")
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let credentials = UntisCredentials(
            server: server.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )
        do {
            try await UntisService.shared.authenticate(with: credentials)
            try KeychainHelper.save(credentials: credentials)
            appState.isAuthenticated = true
            Task { try? await SyncService.shared.performSync() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SetupView()
        .environment(AppState.shared)
}
