import Foundation

struct Workout: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let estimatedDurationMinutes: Int
    let scheduledDate: Date
    let status: WorkoutStatus
    let exercises: [Exercise]

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        estimatedDurationMinutes: Int,
        scheduledDate: Date,
        status: WorkoutStatus,
        exercises: [Exercise]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.scheduledDate = scheduledDate
        self.status = status
        self.exercises = exercises
    }
}

enum WorkoutStatus: Hashable {
    case scheduled
    case completed
}
