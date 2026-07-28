import Foundation

struct Athlete {
    let userID: UUID
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let heightInches: Double
    let weightPounds: Double
    let position: AthletePosition
    let team: String
    let graduationYear: Int
    let shoots: ShootingSide
    let trainingGoals: String
}

enum AthletePosition: String, CaseIterable, Identifiable {
    case center = "Center"
    case leftWing = "Left Wing"
    case rightWing = "Right Wing"
    case defense = "Defense"
    case goalie = "Goalie"
    case other = "Other"

    var id: Self { self }
}

enum ShootingSide: String, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"

    var id: Self { self }
}
