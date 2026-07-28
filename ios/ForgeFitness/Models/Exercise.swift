import Foundation

struct Exercise: Identifiable, Hashable {
    let id: UUID
    let name: String
    let sets: Int
    let reps: String
    let restSeconds: Int
    let coachNotes: String

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: String,
        restSeconds: Int,
        coachNotes: String
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.coachNotes = coachNotes
    }
}
