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
        let profile = AthletePayload(
            userID: athlete.userID,
            firstName: athlete.firstName,
            lastName: athlete.lastName,
            dateOfBirth: Self.dateFormatter.string(
                from: athlete.dateOfBirth
            ),
            heightInches: Int(athlete.heightInches.rounded()),
            weightPounds: Int(athlete.weightPounds.rounded()),
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

    func loadCurrentProfile() async throws -> Athlete {
        let userID = try await currentUserID()
        let profiles: [AthleteRecord] = try await client
            .from("athletes")
            .select()
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value

        guard let profile = profiles.first else {
            throw AthleteServiceError.profileNotFound
        }

        return try profile.athlete
    }

    func updateProfile(_ athlete: Athlete) async throws {
        let userID = try await currentUserID()
        guard athlete.userID == userID else {
            throw AthleteServiceError.unauthorized
        }

        let profile = AthletePayload(
            userID: athlete.userID,
            firstName: athlete.firstName,
            lastName: athlete.lastName,
            dateOfBirth: Self.dateFormatter.string(from: athlete.dateOfBirth),
            heightInches: Int(athlete.heightInches.rounded()),
            weightPounds: Int(athlete.weightPounds.rounded()),
            position: athlete.position.rawValue,
            team: athlete.team,
            graduationYear: athlete.graduationYear,
            shoots: athlete.shoots.rawValue,
            trainingGoals: athlete.trainingGoals
        )

        try await client
            .from("athletes")
            .update(profile)
            .eq("user_id", value: userID)
            .execute()
    }

    func loadCoachAthletes() async throws -> [Athlete] {
        let profiles: [AthleteRecord] = try await client
            .from("athletes")
            .select()
            .order("last_name")
            .execute()
            .value

        return try profiles.map { profile in
            try profile.athlete
        }
    }

    func currentUserID() async throws -> UUID {
        try await client.auth.session.user.id
    }

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum AthleteServiceError: LocalizedError {
    case profileNotFound
    case invalidProfile
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            "Your athlete profile could not be found."
        case .invalidProfile:
            "The athlete profile contains invalid data."
        case .unauthorized:
            "You do not have permission to update this profile."
        }
    }
}

private struct AthleteID: Decodable {
    let id: UUID
}

private struct AthletePayload: Encodable {
    let userID: UUID
    let firstName: String
    let lastName: String
    let dateOfBirth: String
    let heightInches: Int
    let weightPounds: Int
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

private struct AthleteRecord: Decodable {
    let userID: UUID
    let firstName: String?
    let lastName: String?
    let dateOfBirth: String?
    let heightInches: Int?
    let weightPounds: Int?
    let position: String?
    let team: String?
    let graduationYear: Int?
    let shoots: String?
    let trainingGoals: String?

    var athlete: Athlete {
        get throws {
            guard let firstName,
                  let lastName,
                  let dateOfBirth,
                  let birthDate = AthleteService.dateFormatter.date(
                    from: dateOfBirth
                  ),
                  let heightInches,
                  let weightPounds,
                  let positionValue = position,
                  let position = AthletePosition(rawValue: positionValue),
                  let team,
                  let graduationYear,
                  let shootsValue = shoots,
                  let shoots = ShootingSide(rawValue: shootsValue),
                  let trainingGoals else {
                throw AthleteServiceError.invalidProfile
            }

            return Athlete(
                userID: userID,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: birthDate,
                heightInches: Double(heightInches),
                weightPounds: Double(weightPounds),
                position: position,
                team: team,
                graduationYear: graduationYear,
                shoots: shoots,
                trainingGoals: trainingGoals
            )
        }
    }

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
