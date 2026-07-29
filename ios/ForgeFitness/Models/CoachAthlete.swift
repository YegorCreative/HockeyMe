import Foundation

struct CoachAthlete: Identifiable {
    let id: UUID
    let name: String
    let team: String
    let position: String
    let graduationYear: Int
    let lastWorkout: String
    let compliance: Int
    let recoveryScore: Int
    let profile: CoachAthleteProfile
    let recentWorkouts: [CoachWorkoutRecord]
    let performance: [CoachMetric]
    let recovery: [CoachMetric]
    let coachNotes: String
    let assignedProgram: String
}

struct CoachAthleteProfile {
    let age: Int
    let height: String
    let weight: String
    let shoots: String
}

struct CoachWorkoutRecord: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let status: String
}

struct CoachMetric: Identifiable {
    let title: String
    let value: String
    let trend: String

    var id: String { title }
}
