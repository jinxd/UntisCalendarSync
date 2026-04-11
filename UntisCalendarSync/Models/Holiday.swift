import Foundation

struct Holiday: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let startDate: Date
    let endDate: Date

    func contains(_ date: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        return d >= cal.startOfDay(for: startDate) && d <= cal.startOfDay(for: endDate)
    }
}
