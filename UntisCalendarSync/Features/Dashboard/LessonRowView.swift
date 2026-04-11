import SwiftUI

struct LessonRowView: View {
    let lesson: Lesson

    private var statusColor: Color {
        switch lesson.status {
        case .substitution: return .orange
        case .exam:         return .purple
        case .additional:   return .green
        default:            return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                Text(lesson.displayTitle)
                    .fontWeight(.medium)
                    .strikethrough(lesson.status == .cancelled)
                    .foregroundStyle(lesson.status == .cancelled ? .secondary : .primary)

                if lesson.status != .normal && lesson.status != .cancelled {
                    Text(lesson.status.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor)
                }
            }

            if !lesson.rooms.isEmpty {
                Text(lesson.rooms.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !lesson.teachers.isEmpty {
                Text(lesson.teachers.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(lesson.status == .cancelled ? 0.6 : 1)
    }
}
