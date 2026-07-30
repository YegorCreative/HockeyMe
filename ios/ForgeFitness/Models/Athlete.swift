import Foundation

struct Athlete: Codable {
    let id: UUID
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

    init(
        id: UUID = UUID(),
        userID: UUID,
        firstName: String,
        lastName: String,
        dateOfBirth: Date,
        heightInches: Double,
        weightPounds: Double,
        position: AthletePosition,
        team: String,
        graduationYear: Int,
        shoots: ShootingSide,
        trainingGoals: String
    ) {
        self.id = id
        self.userID = userID
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.heightInches = heightInches
        self.weightPounds = weightPounds
        self.position = position
        self.team = team
        self.graduationYear = graduationYear
        self.shoots = shoots
        self.trainingGoals = trainingGoals
    }
}

enum AthletePosition: String, CaseIterable, Identifiable, Codable {
    case center = "Center"
    case leftWing = "Left Wing"
    case rightWing = "Right Wing"
    case defense = "Defense"
    case goalie = "Goalie"
    case other = "Other"

    var id: Self { self }
}

enum ShootingSide: String, CaseIterable, Identifiable, Codable {
    case left = "Left"
    case right = "Right"

    var id: Self { self }
}
