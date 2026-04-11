import Foundation
import EventKit

@MainActor
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    private let calendarTitle = "Untis"
    private let urlScheme = "untis"

    private init() {}

    // MARK: - Authorization

    func requestAccess() async throws {
        try await store.requestFullAccessToEvents()
    }

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    // MARK: - Calendar management

    func getOrCreateUntisCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        if let source = preferredSource() {
            calendar.source = source
        }
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    private func preferredSource() -> EKSource? {
        // Prefer iCloud, then local
        store.sources.first { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }
            ?? store.sources.first { $0.sourceType == .local }
            ?? store.defaultCalendarForNewEvents?.source
    }

    // MARK: - Sync

    func syncLessons(_ lessons: [Lesson], in calendar: EKCalendar) throws {
        // Sync window: today-8 days … end of fetched data (or today+365 as upper bound)
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-8 * 86400)
        let end   = lessons.map(\.endDate).max()?.addingTimeInterval(86400)
                    ?? Calendar.current.startOfDay(for: Date()).addingTimeInterval(366 * 86400)

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        let existing  = store.events(matching: predicate)

        // Build map: periodId → existing event
        var existingMap: [Int: EKEvent] = [:]
        for event in existing {
            if let url = event.url,
               url.scheme == urlScheme,
               let periodId = Int(url.host ?? "") {
                existingMap[periodId] = event
            }
        }

        let activeLessons = lessons.filter { $0.status != .cancelled }
        let activeLessonIds = Set(activeLessons.map(\.id))

        // Delete events that no longer exist or are now cancelled
        for (periodId, event) in existingMap where !activeLessonIds.contains(periodId) {
            try store.remove(event, span: .thisEvent, commit: false)
        }

        // Create or update active lessons only
        for lesson in activeLessons {
            if let existing = existingMap[lesson.id] {
                applyLesson(lesson, to: existing)
                try store.save(existing, span: .thisEvent, commit: false)
            } else {
                let event = makeEvent(from: lesson, in: calendar)
                try store.save(event, span: .thisEvent, commit: false)
            }
        }

        try store.commit()
    }

    // MARK: - Helpers

    private func makeEvent(from lesson: Lesson, in calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        applyLesson(lesson, to: event)
        return event
    }

    private func applyLesson(_ lesson: Lesson, to event: EKEvent) {
        let roomSuffix = lesson.rooms.isEmpty ? "" : " (\(lesson.rooms.joined(separator: ", ")))"
        event.title     = lesson.displayTitle + roomSuffix
        event.startDate = lesson.startDate
        event.endDate   = lesson.endDate
        event.location  = lesson.rooms.joined(separator: ", ")
        event.url       = URL(string: "\(urlScheme)://\(lesson.id)")

        var noteParts: [String] = []
        if !lesson.rooms.isEmpty    { noteParts.append("Room: \(lesson.rooms.joined(separator: ", "))") }
        if !lesson.teachers.isEmpty { noteParts.append("Teacher: \(lesson.teachers.joined(separator: ", "))") }
        if !lesson.notes.isEmpty    { noteParts.append(lesson.notes) }
        event.notes = noteParts.isEmpty ? nil : noteParts.joined(separator: "\n")
    }
}
