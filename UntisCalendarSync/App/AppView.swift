import SwiftUI

struct AppView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @State private var timetableScrollTrigger = 0

    var body: some View {
        if appState.isAuthenticated {
            TabView(selection: tabSelection) {
                Tab("Timetable", systemImage: "calendar", value: 0) {
                    DashboardView(scrollToHomeTrigger: timetableScrollTrigger)
                }
                Tab("Settings", systemImage: "gearshape", value: 1) {
                    SettingsView()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && !appState.isSyncing {
                    Task { try? await SyncService.shared.performSync() }
                }
            }
        } else {
            SetupView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab, newTab == 0 {
                    timetableScrollTrigger += 1
                }
                selectedTab = newTab
            }
        )
    }
}

#Preview {
    AppView()
        .environment(AppState.shared)
}
