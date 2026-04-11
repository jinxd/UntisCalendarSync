import Foundation

struct Lesson: Identifiable, Hashable, Codable {
    let id: Int
    let date: Date
    let startDate: Date
    let endDate: Date
    let subjects: [String]
    let teachers: [String]
    let rooms: [String]
    let status: LessonStatus
    let notes: String

    var title: String {
        subjects.joined(separator: ", ").isEmpty ? "Lesson" : subjects.joined(separator: ", ")
    }

    var displayTitle: String { title }
}

enum LessonStatus: String, Codable, Hashable {
    case normal
    case cancelled
    case substitution
    case exam
    case additional

    var displayName: String {
        switch self {
        case .normal:       return "Normal"
        case .cancelled:    return "Cancelled"
        case .substitution: return "Substitution"
        case .exam:         return "Exam"
        case .additional:   return "Additional"
        }
    }
}
