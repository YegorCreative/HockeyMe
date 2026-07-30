import Foundation

struct Workout: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let description: String
    let estimatedDurationMinutes: Int
    let scheduledDate: Date
    let status: WorkoutStatus
    let exercises: [WorkoutExercise]
    let assignmentID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        estimatedDurationMinutes: Int,
        scheduledDate: Date,
        status: WorkoutStatus,
        exercises: [WorkoutExercise],
        assignmentID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.scheduledDate = scheduledDate
        self.status = status
        self.exercises = exercises
        self.assignmentID = assignmentID
    }
}

enum WorkoutStatus: Hashable, Codable {
    case scheduled
    case completed
}
