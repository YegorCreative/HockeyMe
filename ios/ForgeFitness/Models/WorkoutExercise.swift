import Foundation

struct WorkoutExercise: Identifiable, Hashable {
    let id: UUID
    let name: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    let coachNotes: String
    let exerciseID: UUID
    let exerciseDescription: String?
    let category: String?
    let difficulty: String?

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: String,
        restSeconds: Int,
        coachNotes: String,
        exerciseID: UUID? = nil,
        exerciseDescription: String? = nil,
        category: String? = nil,
        difficulty: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.coachNotes = coachNotes
        self.exerciseID = exerciseID ?? id
        self.exerciseDescription = exerciseDescription
        self.category = category
        self.difficulty = difficulty
    }
}
