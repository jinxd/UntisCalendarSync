import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDate: Date
    var onDaySelected: (() -> Void)? = nil

    private let cal = Calendar.current

    private var weekDays: [Date] {
        let start = firstDayOfWeek(containing: selectedDate)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(weekDays.first ?? selectedDate, format: .dateTime.month(.wide).year())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button { jumpWeeks(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 32)
                }
                Button { jumpWeeks(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 32)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HStack {
                ForEach(weekDays, id: \.self) { day in
                    DayChip(
                        day: day,
                        isSelected: cal.isDate(day, inSameDayAs: selectedDate),
                        isToday: cal.isDateInToday(day),
                        isWeekend: cal.isDateInWeekend(day)
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedDate = day
                            onDaySelected?()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    private func jumpWeeks(by offset: Int) {
        guard let newStart = cal.date(byAdding: .weekOfYear, value: offset, to: firstDayOfWeek(containing: selectedDate)) else { return }
        // Land on the first non-weekend day of the target week
        var target = newStart
        for _ in 0..<7 {
            if !cal.isDateInWeekend(target) { break }
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        selectedDate = target
    }

    private func firstDayOfWeek(containing date: Date) -> Date {
        let d = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: d)
        let daysBack = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -daysBack, to: d)!
    }
}

private struct DayChip: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let isWeekend: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Text(day, format: .dateTime.weekday(.narrow))
                    .font(.caption2)
                    .foregroundStyle(
                        isWeekend ? Color(.tertiaryLabel) :
                        isSelected ? Color.accentColor :
                        Color(.secondaryLabel)
                    )
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 32, height: 32)
                    } else if isToday {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }
                    Text(day, format: .dateTime.day())
                        .font(.callout)
                        .fontWeight(isToday || isSelected ? .semibold : .regular)
                        .foregroundStyle(
                            isSelected ? Color.white :
                            isWeekend ? Color(.tertiaryLabel) :
                            Color.primary
                        )
                }
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .disabled(isWeekend)
    }
}

#Preview {
    WeekStripView(selectedDate: .constant(Date()))
}
