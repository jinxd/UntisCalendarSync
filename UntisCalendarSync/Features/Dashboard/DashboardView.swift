import SwiftUI

struct DashboardView: View {
    var scrollToHomeTrigger: Int = 0

    @Environment(AppState.self) private var appState
    @State private var selectedDate: Date = {
        let cal = Calendar.current
        var date = cal.startOfDay(for: Date())
        while cal.isDateInWeekend(date) {
            date = cal.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }()

    private let cal = Calendar.current

    private var displayedDays: [Date] {
        let today = cal.startOfDay(for: Date())
        let start = firstDayOfWeek(containing: cal.date(byAdding: .weekOfYear, value: -1, to: today)!)
        let defaultEnd = cal.date(byAdding: .day, value: 42, to: today)!
        let dataEnd = appState.lessons.map { cal.startOfDay(for: $0.startDate) }.max() ?? defaultEnd
        let end = dataEnd > defaultEnd ? dataEnd : defaultEnd

        var days: [Date] = []
        var d = start
        while d <= end {
            if !cal.isDateInWeekend(d) { days.append(d) }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return days
    }

    private var lessonsByDay: [Date: [[Lesson]]] {
        Dictionary(grouping: appState.lessons) { cal.startOfDay(for: $0.startDate) }
            .mapValues { groupByProximity($0.sorted { $0.startDate < $1.startDate }) }
    }

    /// The nearest day on or after today that has at least one lesson.
    private var nextDayWithLessons: Date? {
        let today = cal.startOfDay(for: Date())
        return displayedDays.first { $0 >= today && !(lessonsByDay[$0] ?? []).isEmpty }
    }

    @State private var showStrip = false
    @State private var hasScrolledToInitialPosition = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                        if let error = appState.syncError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .listRowSeparator(.hidden)
                        }

                        ForEach(displayedDays, id: \.self) { day in
                            let groups = lessonsByDay[day] ?? []
                            let holiday = appState.holidays.first { $0.contains(day) }
                            let isNext = nextDayWithLessons.map { cal.isDate($0, inSameDayAs: day) } ?? false

                            // Day header row — carries the scroll anchor
                            HStack(alignment: .lastTextBaseline) {
                                VStack(alignment: .leading) {
                                    Text(day, format: .dateTime.weekday(.wide))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(isNext ? Color.accentColor : Color.primary)
                                    Text(day, format: .dateTime.day().month().year())
                                        .font(.subheadline)
                                        .foregroundStyle(isNext ? Color.accentColor.opacity(0.7) : Color.secondary)
                                }
                                Spacer()
                                if let holiday {
                                    Label(holiday.name, systemImage: "sun.max.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .lineLimit(1)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.top, 16)
                            .id(day)

                            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                                Section {
                                    ForEach(group) { lesson in
                                        NavigationLink {
                                            LessonDetailView(lesson: lesson)
                                        } label: {
                                            LessonRowView(lesson: lesson)
                                        }
                                    }
                                } header: {
                                    Text(group.first!.startDate, format: .dateTime.hour().minute())
                                } footer: {
                                    Text(group.last!.endDate, format: .dateTime.hour().minute())
                                }
                            }
                        }
                    }
                .onChange(of: selectedDate) { old, new in
                    guard !cal.isDate(old, inSameDayAs: new) else { return }
                    withAnimation { proxy.scrollTo(new, anchor: .top) }
                }
                .onChange(of: scrollToHomeTrigger) {
                    withAnimation { proxy.scrollTo(selectedDate, anchor: .top) }
                }
                .onAppear {
                    guard !hasScrolledToInitialPosition else { return }
                    hasScrolledToInitialPosition = true
                    withAnimation { proxy.scrollTo(selectedDate, anchor: .top) }
                }
                .overlay(alignment: .top) {
                    if showStrip {
                        WeekStripView(selectedDate: $selectedDate) {
                            showStrip = false
                        }
                        .background(.bar)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.3), value: showStrip)
            }
            .navigationTitle("Timetable")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showStrip.toggle() }
                    } label: {
                        Image(systemName: "calendar")
                            .symbolVariant(showStrip ? .fill : .none)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { try? await SyncService.shared.performSync() }
                    } label: {
                        if appState.isSyncing {
                            ProgressView()
                        } else {
                            Label("Sync", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(appState.isSyncing)
                }
            }
        }
    }

    private func groupByProximity(_ lessons: [Lesson]) -> [[Lesson]] {
        guard !lessons.isEmpty else { return [] }
        var groups: [[Lesson]] = [[lessons[0]]]
        for lesson in lessons.dropFirst() {
            let gap = lesson.startDate.timeIntervalSince(groups.last!.last!.endDate)
            if gap < 45 * 60 {
                groups[groups.count - 1].append(lesson)
            } else {
                groups.append([lesson])
            }
        }
        return groups
    }

    private func firstDayOfWeek(containing date: Date) -> Date {
        let d = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: d)
        let daysBack = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -daysBack, to: d)!
    }
}

#Preview {
    DashboardView()
        .environment(AppState.shared)
}
