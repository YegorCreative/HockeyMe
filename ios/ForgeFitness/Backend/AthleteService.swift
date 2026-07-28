import Foundation
import Supabase

final class AthleteService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func hasProfile() async throws -> Bool {
        let userID = try await currentUserID()
        let profiles: [AthleteID] = try await client
            .from("athletes")
            .select("id")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value

        return !profiles.isEmpty
    }

    func saveProfile(_ athlete: Athlete) async throws {
        let profile = AthleteInsert(
            userID: athlete.userID,
            firstName: athlete.firstName,
            lastName: athlete.lastName,
            dateOfBirth: Self.dateFormatter.string(
                from: athlete.dateOfBirth
            ),
            heightInches: athlete.heightInches,
            weightPounds: athlete.weightPounds,
            position: athlete.position.rawValue,
            team: athlete.team,
            graduationYear: athlete.graduationYear,
            shoots: athlete.shoots.rawValue,
            trainingGoals: athlete.trainingGoals
        )

        try await client
            .from("athletes")
            .insert(profile)
            .execute()
    }

    func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct AthleteID: Decodable {
    let id: UUID
}

private struct AthleteInsert: Encodable {
    let userID: UUID
    let firstName: String
    let lastName: String
    let dateOfBirth: String
    let heightInches: Double
    let weightPounds: Double
    let position: String
    let team: String
    let graduationYear: Int
    let shoots: String
    let trainingGoals: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case heightInches = "height_inches"
        case weightPounds = "weight_pounds"
        case position
        case team
        case graduationYear = "graduation_year"
        case shoots
        case trainingGoals = "training_goals"
    }
}
