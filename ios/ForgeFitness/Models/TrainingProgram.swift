import Foundation

enum TrainingProgramStatus: String {
    case draft
    case published = "active"
    case archived
}

struct TrainingProgram: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var status: TrainingProgramStatus
    var durationWeeks: Int
    var weeks: [TrainingProgramWeek]
}

struct TrainingProgramWeek: Identifiable {
    let id: UUID
    var weekNumber: Int
    var name: String
    var focus: String
    var workouts: [ProgramWorkout]
}

struct ProgramWorkout: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var dayNumber: Int
    var estimatedDurationMinutes: Int
    var sortOrder: Int
    var exercises: [ProgramExercise]
}

struct ProgramExercise: Identifiable {
    let id: UUID
    let exerciseID: UUID
    let name: String
    var sets: Int
    var repsMin: Int
    var repsMax: Int
    var restSeconds: Int
    var tempo: String
    var notes: String
    var coachCues: String
    var sortOrder: Int
}

struct ProgramExerciseChoice: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let difficulty: String
}

struct ProgramAthlete: Identifiable {
    let id: UUID
    let name: String
    let team: String
    let position: String
    let graduationYear: Int
    var assignmentID: UUID?

    var isAssigned: Bool { assignmentID != nil }
}
