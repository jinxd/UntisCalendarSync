import SwiftUI
import EventKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showLogoutConfirmation = false
    @State private var calendarName = ""

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                syncSection
                calendarSection
                dangerSection
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) { logout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your credentials. Synced calendar events will remain.")
            }
            .onAppear { loadCalendarName() }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let credentials = try? KeychainHelper.loadCredentials() {
                LabeledContent("Server",   value: credentials.server)
                LabeledContent("Username", value: credentials.username)
            }
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        Section("Sync") {
            if let last = appState.lastSyncDate {
                LabeledContent("Last Sync", value: last.formatted(date: .abbreviated, time: .shortened))
            } else {
                LabeledContent("Last Sync", value: "Never")
            }

            Button {
                Task { try? await SyncService.shared.performSync() }
            } label: {
                HStack {
                    if appState.isSyncing { ProgressView() }
                    Text(appState.isSyncing ? "Syncing…" : "Sync Now")
                }
            }
            .disabled(appState.isSyncing)
        }
    }

    @ViewBuilder
    private var calendarSection: some View {
        Section("Calendar") {
            LabeledContent("Calendar", value: calendarName.isEmpty ? "Untis (will be created)" : calendarName)
            if CalendarService.shared.hasAccess {
                Label("Calendar access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant Calendar Access") {
                    Task { try? await CalendarService.shared.requestAccess() }
                }
            }
        }
    }

    @ViewBuilder
    private var dangerSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                showLogoutConfirmation = true
            }
        }
    }

    private func loadCalendarName() {
        guard CalendarService.shared.hasAccess,
              let cal = try? CalendarService.shared.getOrCreateUntisCalendar() else { return }
        calendarName = cal.title
    }

    private func logout() {
        KeychainHelper.deleteCredentials()
        appState.isAuthenticated = false
        appState.lessons = []
        appState.lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: "cachedLessons")
    }
}

#Preview {
    SettingsView()
        .environment(AppState.shared)
}
