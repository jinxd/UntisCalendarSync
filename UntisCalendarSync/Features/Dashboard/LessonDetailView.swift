import SwiftUI

struct LessonDetailView: View {
    let lesson: Lesson

    var body: some View {
        Form {
            Section("Time") {
                LabeledContent("Start", value: lesson.startDate.formatted(date: .omitted, time: .shortened))
                LabeledContent("End",   value: lesson.endDate.formatted(date: .omitted, time: .shortened))
            }

            Section("Details") {
                if !lesson.subjects.isEmpty {
                    LabeledContent("Subject", value: lesson.subjects.joined(separator: ", "))
                }
                if !lesson.rooms.isEmpty {
                    LabeledContent("Room", value: lesson.rooms.joined(separator: ", "))
                }
                if !lesson.teachers.isEmpty {
                    LabeledContent("Teacher", value: lesson.teachers.joined(separator: ", "))
                }
                if lesson.status != .normal {
                    LabeledContent("Status", value: lesson.status.displayName)
                }
                if !lesson.notes.isEmpty {
                    LabeledContent("Notes", value: lesson.notes)
                }
            }

            Section {
                Label("Absence reporting is not available via the WebUntis API. Use the official Untis app.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
