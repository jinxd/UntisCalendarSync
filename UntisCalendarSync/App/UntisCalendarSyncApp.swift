import SwiftUI
import BackgroundTasks

@main
struct UntisCalendarSyncApp: App {
    private let appState = AppState.shared

    init() {
        SyncService.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(appState)
        }
    }
}
