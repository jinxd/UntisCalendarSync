import Foundation
import BackgroundTasks

private let refreshTaskIdentifier = "com.nagel.UntisCalendarSync.refresh"

@MainActor
final class SyncService {
    static let shared = SyncService()
    private init() {}

    func performSync() async throws {
        let appState = AppState.shared
        appState.isSyncing = true
        appState.syncError = nil
        defer { appState.isSyncing = false }

        let credentials = try KeychainHelper.loadCredentials()
        let untis = UntisService.shared
        try await untis.authenticate(with: credentials)

        let allLessons = try await untis.fetchAllLessons()
        let holidays   = try await untis.fetchHolidays()

        let calService = CalendarService.shared
        if !calService.hasAccess {
            try await calService.requestAccess()
        }
        let calendar = try calService.getOrCreateUntisCalendar()
        try calService.syncLessons(allLessons, in: calendar)

        appState.lessons = allLessons.sorted { $0.startDate < $1.startDate }
        appState.holidays = holidays
        appState.lastSyncDate = Date()
        appState.cacheLessons(allLessons)
        appState.cacheHolidays(holidays)
        scheduleNextRefresh()
    }

    // MARK: - Background task

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let syncTask = Task {
                do {
                    try await SyncService.shared.performSync()
                    refreshTask.setTaskCompleted(success: true)
                } catch {
                    refreshTask.setTaskCompleted(success: false)
                }
            }
            refreshTask.expirationHandler = {
                syncTask.cancel()
            }
        }
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
