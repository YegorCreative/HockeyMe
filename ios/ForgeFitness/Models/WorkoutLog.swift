import Foundation

struct WorkoutSetLog: Identifiable, Codable {
    let id: UUID
    let exerciseID: UUID
    let exerciseName: String
    let setNumber: Int
    let weight: Double
    let reps: Int
    let rpe: Int
    let painLevel: Int
    let notes: String
    let completedAt: Date

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseName: String,
        setNumber: Int,
        weight: Double,
        reps: Int,
        rpe: Int,
        painLevel: Int,
        notes: String,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.painLevel = painLevel
        self.notes = notes
        self.completedAt = completedAt
    }
}

struct PreviousWorkoutValue: Codable {
    let weight: Double
    let reps: Int
    let rpe: Int
}

struct WorkoutSessionSummary: Codable {
    let totalVolume: Double
    let totalSets: Int
    let totalReps: Int
    let durationSeconds: Int
    let personalRecords: [String]
}
