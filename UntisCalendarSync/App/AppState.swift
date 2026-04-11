import Foundation

@MainActor @Observable
final class AppState {
    static let shared = AppState()

    var isAuthenticated: Bool
    var isSyncing = false
    var syncError: String?
    var lessons: [Lesson] = []
    var holidays: [Holiday] = []
    var lastSyncDate: Date? {
        didSet { UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate") }
    }

    private init() {
        isAuthenticated = KeychainHelper.hasCredentials()
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        lessons = loadCached(key: "cachedLessons", as: [Lesson].self)
        holidays = loadCached(key: "cachedHolidays", as: [Holiday].self)
    }

    func cacheLessons(_ lessons: [Lesson]) {
        persist(lessons, key: "cachedLessons")
    }

    func cacheHolidays(_ holidays: [Holiday]) {
        persist(holidays, key: "cachedHolidays")
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadCached<T: Decodable>(key: String, as type: T.Type) -> T where T: ExpressibleByArrayLiteral {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(type, from: data) else { return [] }
        return value
    }
}
