import Foundation

enum OrganizationRole: String, Codable, CaseIterable, Identifiable {
    case organizationOwner = "organization_owner"
    case administrator
    case headCoach = "head_coach"
    case assistantCoach = "assistant_coach"
    case strengthCoach = "strength_coach"
    case athleticTrainer = "athletic_trainer"
    case athlete
    case parent

    var id: Self { self }

    var title: String {
        switch self {
        case .organizationOwner: "Organization Owner"
        case .headCoach: "Head Coach"
        case .assistantCoach: "Assistant Coach"
        case .strengthCoach: "Strength Coach"
        case .athleticTrainer: "Athletic Trainer"
        default: rawValue.capitalized
        }
    }

    var isStaff: Bool {
        switch self {
        case .organizationOwner, .administrator, .headCoach,
             .assistantCoach, .strengthCoach, .athleticTrainer:
            true
        case .athlete, .parent:
            false
        }
    }
}

struct Organization: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var slug: String
    let ownerUserID: UUID
}

struct OrganizationMembership: Identifiable, Codable, Hashable {
    let id: UUID
    let organizationID: UUID
    let userID: UUID
    var displayName: String
    var email: String
    var roles: [OrganizationRole]
    var status: String
}

struct OrganizationTeam: Identifiable, Codable, Hashable {
    let id: UUID
    let organizationID: UUID
    var name: String
    var ageGroup: String
    var isArchived: Bool
}

struct OrganizationSeason: Identifiable, Codable, Hashable {
    let id: UUID
    let organizationID: UUID
    var name: String
    var startsOn: Date
    var endsOn: Date
    var isArchived: Bool
}

struct OrganizationInvitation: Identifiable, Codable, Hashable {
    let id: UUID
    let organizationID: UUID
    let email: String
    let roles: [OrganizationRole]
    let status: String
    let expiresAt: Date
}

struct OrganizationTeamMembership: Identifiable, Codable, Hashable {
    let id: UUID
    let organizationID: UUID
    let teamID: UUID
    let membershipID: UUID
    let role: OrganizationRole
    let athleteID: UUID?
}

struct OrganizationContext: Codable, Hashable {
    let organizations: [Organization]
    let memberships: [OrganizationMembership]
    let teams: [OrganizationTeam]
    let seasons: [OrganizationSeason]

    var roles: Set<OrganizationRole> {
        Set(memberships.flatMap(\.roles))
    }
}

struct OrganizationAnalytics {
    let activeAthletes: Int
    let activeTeams: Int
    let activeCoaches: Int
    let testingCompletion: Double
    let workoutCompliance: Double
    let seasonProgress: Double
}

struct ParentAthleteActivity: Identifiable {
    let id: UUID
    let athleteName: String
    let workoutsCompleted: Int
    let testsCompleted: Int
    let attendancePercent: Double
}
