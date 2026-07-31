import Foundation
import Supabase

enum OrganizationRepositoryError: LocalizedError {
    case invalidName
    case invalidInvitation
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidName:
            "Enter a valid organization or team name."
        case .invalidInvitation:
            "Enter a valid email, role, and expiration."
        case .unavailable:
            "Organization data is currently unavailable."
        }
    }
}

final class OrganizationRepository {
    private let client: SupabaseClient!
    private let offlineStore: OfflineStore
#if DEBUG
    private let developerStore: DeveloperModeStore?
#endif

    init(
        client: SupabaseClient,
        offlineStore: OfflineStore = .shared
    ) {
        self.client = client
        self.offlineStore = offlineStore
#if DEBUG
        developerStore = nil
#endif
    }

#if DEBUG
    init(developerStore: DeveloperModeStore) {
        client = nil
        offlineStore = .shared
        self.developerStore = developerStore
    }
#endif

    func loadContext() async throws -> OrganizationContext {
#if DEBUG
        if let developerStore {
            return await developerStore.organizationContext()
        }
#endif
        let userID = try await client.auth.session.user.id
        do {
            let memberRows: [MembershipRecord] = try await client
                .from("organization_members")
                .select(
                    "id,organization_id,user_id,display_name,email,roles,status,organizations(id,name,slug,owner_user_id)"
                )
                .eq("status", value: "active")
                .is("deleted_at", value: nil)
                .execute()
                .value
            let organizationIDs = memberRows.map(\.organizationID)
            let teams: [TeamRecord]
            let seasons: [SeasonRecord]
            if organizationIDs.isEmpty {
                teams = []
                seasons = []
            } else {
                teams = try await client.from("teams")
                    .select()
                    .in("organization_id", values: organizationIDs)
                    .is("deleted_at", value: nil)
                    .order("name")
                    .execute()
                    .value
                seasons = try await client.from("seasons")
                    .select()
                    .in("organization_id", values: organizationIDs)
                    .is("deleted_at", value: nil)
                    .order("starts_on", ascending: false)
                    .execute()
                    .value
            }
            let organizations = Array(
                Dictionary(
                    grouping: memberRows.map(\.organization),
                    by: \.id
                ).compactMap(\.value.first)
            )
            let context = OrganizationContext(
                organizations: organizations,
                memberships: memberRows.map(\.membership),
                teams: teams.map(\.team),
                seasons: seasons.compactMap(\.season)
            )
            try? await offlineStore.saveOrganizationContext(
                context,
                userID: userID
            )
            return context
        } catch {
            if let cached = await offlineStore.organizationContext(
                userID: userID
            ) {
                return cached
            }
            throw error
        }
    }

    func createOrganization(name: String) async throws -> UUID {
#if DEBUG
        if let developerStore {
            return try await developerStore.createOrganization(name: name)
        }
#endif
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = normalized.lowercased()
            .replacingOccurrences(
                of: "[^a-z0-9]+",
                with: "-",
                options: .regularExpression
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        guard !normalized.isEmpty, !slug.isEmpty else {
            throw OrganizationRepositoryError.invalidName
        }
        let id: UUID = try await client.rpc(
            "create_organization",
            params: [
                "organization_name": normalized,
                "organization_slug": "\(slug)-\(UUID().uuidString.prefix(6).lowercased())"
            ]
        ).execute().value
        return id
    }

    func createTeam(
        organizationID: UUID,
        name: String,
        ageGroup: String
    ) async throws {
#if DEBUG
        if let developerStore {
            try await developerStore.createTeam(
                organizationID: organizationID,
                name: name,
                ageGroup: ageGroup
            )
            return
        }
#endif
        guard !name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw OrganizationRepositoryError.invalidName
        }
        try await client.from("teams")
            .insert(
                TeamInsert(
                    organizationID: organizationID,
                    name: name,
                    ageGroup: ageGroup
                )
            )
            .execute()
    }

    func archiveTeam(id: UUID, archived: Bool) async throws {
#if DEBUG
        if let developerStore {
            await developerStore.archiveTeam(id: id, archived: archived)
            return
        }
#endif
        try await client.from("teams")
            .update(
                ArchiveUpdate(
                    archivedAt: archived ? Self.timestamp(Date()) : nil
                )
            )
            .eq("id", value: id)
            .execute()
    }

    func createSeason(
        organizationID: UUID,
        name: String,
        startsOn: Date,
        endsOn: Date
    ) async throws {
#if DEBUG
        if let developerStore {
            try await developerStore.createSeason(
                organizationID: organizationID,
                name: name,
                startsOn: startsOn,
                endsOn: endsOn
            )
            return
        }
#endif
        guard !name.isEmpty, endsOn >= startsOn else {
            throw OrganizationRepositoryError.invalidName
        }
        try await client.from("seasons")
            .insert(
                SeasonInsert(
                    organizationID: organizationID,
                    name: name,
                    startsOn: Self.day(startsOn),
                    endsOn: Self.day(endsOn)
                )
            )
            .execute()
    }

    func archiveSeason(id: UUID, archived: Bool) async throws {
#if DEBUG
        if let developerStore {
            await developerStore.archiveSeason(id: id, archived: archived)
            return
        }
#endif
        try await client.from("seasons")
            .update(
                ArchiveUpdate(
                    archivedAt: archived ? Self.timestamp(Date()) : nil
                )
            )
            .eq("id", value: id)
            .execute()
    }

    func cloneTeam(
        sourceTeamID: UUID,
        targetSeasonID: UUID,
        name: String
    ) async throws {
#if DEBUG
        if let developerStore {
            try await developerStore.cloneTeam(
                sourceTeamID: sourceTeamID,
                targetSeasonID: targetSeasonID,
                name: name
            )
            return
        }
#endif
        try await client.rpc(
            "clone_team_to_season",
            params: CloneTeamParameters(
                sourceTeamID: sourceTeamID,
                targetSeasonID: targetSeasonID,
                name: name
            )
        ).execute()
    }

    func loadMembers(
        organizationID: UUID
    ) async throws -> [OrganizationMembership] {
#if DEBUG
        if let developerStore {
            return await developerStore.organizationMembers(
                organizationID: organizationID
            )
        }
#endif
        let rows: [MembershipOnlyRecord] = try await client
            .from("organization_members")
            .select(
                "id,organization_id,user_id,display_name,email,roles,status"
            )
            .eq("organization_id", value: organizationID)
            .is("deleted_at", value: nil)
            .order("display_name")
            .execute()
            .value
        return rows.map(\.membership)
    }

    func updateRoles(
        membershipID: UUID,
        roles: [OrganizationRole]
    ) async throws {
#if DEBUG
        if let developerStore {
            try await developerStore.updateMemberRoles(
                membershipID: membershipID,
                roles: roles
            )
            return
        }
#endif
        guard !roles.isEmpty else {
            throw OrganizationRepositoryError.invalidInvitation
        }
        try await client.from("organization_members")
            .update(RoleUpdate(roles: roles))
            .eq("id", value: membershipID)
            .execute()
    }

    func loadTeamMemberships(
        organizationID: UUID
    ) async throws -> [OrganizationTeamMembership] {
#if DEBUG
        if let developerStore {
            return await developerStore.teamMemberships(
                organizationID: organizationID
            )
        }
#endif
        let rows: [TeamMembershipRecord] = try await client
            .from("team_members")
            .select(
                "id,organization_id,team_id,organization_member_id,role,athlete_id"
            )
            .eq("organization_id", value: organizationID)
            .is("deleted_at", value: nil)
            .execute()
            .value
        return rows.map(\.membership)
    }

    func assignMember(
        organizationID: UUID,
        teamID: UUID,
        membershipID: UUID,
        role: OrganizationRole,
        athleteID: UUID? = nil
    ) async throws {
#if DEBUG
        if let developerStore {
            await developerStore.assignMember(
                organizationID: organizationID,
                teamID: teamID,
                membershipID: membershipID,
                role: role,
                athleteID: athleteID
            )
            return
        }
#endif
        try await client.from("team_members")
            .upsert(
                TeamMemberInsert(
                    organizationID: organizationID,
                    teamID: teamID,
                    membershipID: membershipID,
                    role: role,
                    athleteID: athleteID
                )
            )
            .execute()
    }

    func moveAthlete(
        athleteID: UUID,
        organizationID: UUID,
        seasonID: UUID,
        fromTeamID: UUID?,
        toTeamID: UUID
    ) async throws {
#if DEBUG
        if let developerStore {
            try await developerStore.moveAthlete(
                athleteID: athleteID,
                organizationID: organizationID,
                seasonID: seasonID,
                fromTeamID: fromTeamID,
                toTeamID: toTeamID
            )
            return
        }
#endif
        guard let fromTeamID else {
            throw OrganizationRepositoryError.invalidInvitation
        }
        try await client.rpc(
            "move_athlete_to_team",
            params: MoveAthleteParameters(
                organizationID: organizationID,
                athleteID: athleteID,
                seasonID: seasonID,
                fromTeamID: fromTeamID,
                toTeamID: toTeamID
            )
        ).execute()
    }

    func createInvitation(
        organizationID: UUID,
        email: String,
        roles: [OrganizationRole],
        teamIDs: [UUID],
        expiresInHours: Int
    ) async throws {
#if DEBUG
        if let developerStore {
            try await developerStore.createInvitation(
                organizationID: organizationID,
                email: email,
                roles: roles,
                expiresInHours: expiresInHours
            )
            return
        }
#endif
        guard email.contains("@"), !roles.isEmpty else {
            throw OrganizationRepositoryError.invalidInvitation
        }
        try await client.functions.invoke(
            "send-organization-invitation",
            options: FunctionInvokeOptions(
                body: InvitationDeliveryParameters(
                organizationID: organizationID,
                email: email.lowercased(),
                roles: roles,
                teamIDs: teamIDs,
                expiresInHours: expiresInHours
                )
            )
        )
    }

    func loadInvitations(
        organizationID: UUID
    ) async throws -> [OrganizationInvitation] {
#if DEBUG
        if let developerStore {
            return await developerStore.organizationInvitations(
                organizationID: organizationID
            )
        }
#endif
        let rows: [InvitationRecord] = try await client
            .from("invitations")
            .select(
                "id,organization_id,email,roles,status,expires_at"
            )
            .eq("organization_id", value: organizationID)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap(\.invitation)
    }

    func revokeInvitation(id: UUID) async throws {
#if DEBUG
        if let developerStore {
            await developerStore.revokeInvitation(id: id)
            return
        }
#endif
        try await client.rpc(
            "revoke_organization_invitation",
            params: ["check_invitation_id": id.uuidString]
        ).execute()
    }

    func respondToInvitation(
        token: String,
        accept: Bool
    ) async throws {
#if DEBUG
        if developerStore != nil {
            return
        }
#endif
        try await client.rpc(
            "respond_to_organization_invitation",
            params: InvitationResponseParameters(
                rawToken: token,
                acceptInvitation: accept
            )
        ).execute()
    }

    private struct InvitationResponseParameters: Encodable {
        let rawToken: String
        let acceptInvitation: Bool

        enum CodingKeys: String, CodingKey {
            case rawToken = "raw_token"
            case acceptInvitation = "accept_invitation"
        }
    }

    func transferOwnership(
        organizationID: UUID,
        newOwnerUserID: UUID
    ) async throws {
#if DEBUG
        if let developerStore {
            await developerStore.transferOwnership(
                organizationID: organizationID,
                newOwnerUserID: newOwnerUserID
            )
            return
        }
#endif
        try await client.rpc(
            "transfer_organization_ownership",
            params: [
                "check_organization_id": organizationID.uuidString,
                "new_owner_user_id": newOwnerUserID.uuidString
            ]
        ).execute()
    }

    func analytics(
        organizationID: UUID,
        context: OrganizationContext
    ) async throws -> OrganizationAnalytics {
#if DEBUG
        if let developerStore {
            return await developerStore.organizationAnalytics(
                organizationID: organizationID
            )
        }
#endif
        let members = try await loadMembers(organizationID: organizationID)
        let testing: [StatusRecord] = try await client
            .from("testing_sessions")
            .select("status")
            .execute()
            .value
        let workouts: [StatusRecord] = try await client
            .from("workout_sessions")
            .select("status")
            .execute()
            .value
        let activeSeason = context.seasons.first {
            $0.organizationID == organizationID && !$0.isArchived
        }
        let now = Date()
        let seasonProgress: Double
        if let activeSeason {
            let total = activeSeason.endsOn.timeIntervalSince(
                activeSeason.startsOn
            )
            seasonProgress = total <= 0 ? 0 : min(
                100,
                max(
                    0,
                    now.timeIntervalSince(activeSeason.startsOn)
                        / total * 100
                )
            )
        } else {
            seasonProgress = 0
        }
        return OrganizationAnalytics(
            activeAthletes: members.filter {
                $0.roles.contains(.athlete) && $0.status == "active"
            }.count,
            activeTeams: context.teams.filter {
                $0.organizationID == organizationID && !$0.isArchived
            }.count,
            activeCoaches: members.filter {
                $0.roles.contains(where: \.isStaff)
            }.count,
            testingCompletion: Self.completion(testing),
            workoutCompliance: Self.completion(workouts),
            seasonProgress: seasonProgress
        )
    }

    func loadParentActivity() async throws -> [ParentAthleteActivity] {
#if DEBUG
        if let developerStore {
            return await developerStore.parentActivity()
        }
#endif
        let athletes: [ParentAthleteRecord] = try await client
            .from("athletes")
            .select("id,first_name,last_name")
            .execute()
            .value
        let workoutRows: [AthleteStatusRecord] = try await client
            .from("workout_sessions")
            .select("athlete_id,status")
            .execute()
            .value
        let testingRows: [AthleteStatusRecord] = try await client
            .from("testing_sessions")
            .select("athlete_id,status")
            .execute()
            .value
        return athletes.map { athlete in
            let workouts = workoutRows.filter {
                $0.athleteID == athlete.id
            }
            let tests = testingRows.filter {
                $0.athleteID == athlete.id
            }
            let all = workouts + tests
            let complete = all.filter { $0.status == "completed" }.count
            return ParentAthleteActivity(
                id: athlete.id,
                athleteName: "\(athlete.firstName) \(athlete.lastName)",
                workoutsCompleted: workouts.filter {
                    $0.status == "completed"
                }.count,
                testsCompleted: tests.filter {
                    $0.status == "completed"
                }.count,
                attendancePercent: all.isEmpty
                    ? 0
                    : Double(complete) / Double(all.count) * 100
            )
        }
    }

    private static func completion(_ rows: [StatusRecord]) -> Double {
        guard !rows.isEmpty else { return 0 }
        return Double(rows.filter { $0.status == "completed" }.count)
            / Double(rows.count) * 100
    }

    fileprivate static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    fileprivate static func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}

private struct MembershipRecord: Decodable {
    let id: UUID
    let organizationID: UUID
    let userID: UUID
    let displayName: String
    let email: String
    let roles: [OrganizationRole]
    let status: String
    let organizationRecord: OrganizationRecord
    var organization: Organization { organizationRecord.organization }
    var membership: OrganizationMembership {
        OrganizationMembership(
            id: id,
            organizationID: organizationID,
            userID: userID,
            displayName: displayName,
            email: email,
            roles: roles,
            status: status
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, roles, status, email
        case organizationID = "organization_id"
        case userID = "user_id"
        case displayName = "display_name"
        case organizationRecord = "organizations"
    }
}

private struct MembershipOnlyRecord: Decodable {
    let id: UUID
    let organizationID: UUID
    let userID: UUID
    let displayName: String
    let email: String
    let roles: [OrganizationRole]
    let status: String
    var membership: OrganizationMembership {
        OrganizationMembership(
            id: id,
            organizationID: organizationID,
            userID: userID,
            displayName: displayName,
            email: email,
            roles: roles,
            status: status
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, roles, status, email
        case organizationID = "organization_id"
        case userID = "user_id"
        case displayName = "display_name"
    }
}

private struct OrganizationRecord: Decodable {
    let id: UUID
    let name: String
    let slug: String
    let ownerUserID: UUID
    var organization: Organization {
        Organization(
            id: id,
            name: name,
            slug: slug,
            ownerUserID: ownerUserID
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name, slug
        case ownerUserID = "owner_user_id"
    }
}

private struct TeamRecord: Decodable {
    let id: UUID
    let organizationID: UUID
    let name: String
    let ageGroup: String
    let archivedAt: String?
    var team: OrganizationTeam {
        OrganizationTeam(
            id: id,
            organizationID: organizationID,
            name: name,
            ageGroup: ageGroup,
            isArchived: archivedAt != nil
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name
        case organizationID = "organization_id"
        case ageGroup = "age_group"
        case archivedAt = "archived_at"
    }
}

private struct SeasonRecord: Decodable {
    let id: UUID
    let organizationID: UUID
    let name: String
    let startsOn: String
    let endsOn: String
    let archivedAt: String?
    var season: OrganizationSeason? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startsOn),
              let end = formatter.date(from: endsOn) else { return nil }
        return OrganizationSeason(
            id: id,
            organizationID: organizationID,
            name: name,
            startsOn: start,
            endsOn: end,
            isArchived: archivedAt != nil
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name
        case organizationID = "organization_id"
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case archivedAt = "archived_at"
    }
}

private struct InvitationRecord: Decodable {
    let id: UUID
    let organizationID: UUID
    let email: String
    let roles: [OrganizationRole]
    let status: String
    let expiresAt: String
    var invitation: OrganizationInvitation? {
        guard let date = OrganizationRepository.date(expiresAt) else {
            return nil
        }
        return OrganizationInvitation(
            id: id,
            organizationID: organizationID,
            email: email,
            roles: roles,
            status: status,
            expiresAt: date
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, email, roles, status
        case organizationID = "organization_id"
        case expiresAt = "expires_at"
    }
}

private struct StatusRecord: Decodable {
    let status: String
}

private struct AthleteStatusRecord: Decodable {
    let athleteID: UUID
    let status: String
    enum CodingKeys: String, CodingKey {
        case athleteID = "athlete_id"
        case status
    }
}

private struct ParentAthleteRecord: Decodable {
    let id: UUID
    let firstName: String
    let lastName: String
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

private struct TeamMembershipRecord: Decodable {
    let id: UUID
    let organizationID: UUID
    let teamID: UUID
    let membershipID: UUID
    let role: OrganizationRole
    let athleteID: UUID?
    var membership: OrganizationTeamMembership {
        OrganizationTeamMembership(
            id: id,
            organizationID: organizationID,
            teamID: teamID,
            membershipID: membershipID,
            role: role,
            athleteID: athleteID
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, role
        case organizationID = "organization_id"
        case teamID = "team_id"
        case membershipID = "organization_member_id"
        case athleteID = "athlete_id"
    }
}

private struct TeamInsert: Encodable {
    let organizationID: UUID
    let name: String
    let ageGroup: String
    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case name
        case ageGroup = "age_group"
    }
}

private struct SeasonInsert: Encodable {
    let organizationID: UUID
    let name: String
    let startsOn: String
    let endsOn: String
    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case name
        case startsOn = "starts_on"
        case endsOn = "ends_on"
    }
}

private struct ArchiveUpdate: Encodable {
    let archivedAt: String?
    enum CodingKeys: String, CodingKey {
        case archivedAt = "archived_at"
    }
}

private struct RoleUpdate: Encodable {
    let roles: [OrganizationRole]
}

private struct TeamMemberInsert: Encodable {
    let organizationID: UUID
    let teamID: UUID
    let membershipID: UUID
    let role: OrganizationRole
    let athleteID: UUID?
    enum CodingKeys: String, CodingKey {
        case role
        case organizationID = "organization_id"
        case teamID = "team_id"
        case membershipID = "organization_member_id"
        case athleteID = "athlete_id"
    }
}

private struct MoveAthleteParameters: Encodable {
    let organizationID: UUID
    let athleteID: UUID
    let seasonID: UUID
    let fromTeamID: UUID
    let toTeamID: UUID
    enum CodingKeys: String, CodingKey {
        case organizationID = "check_organization_id"
        case athleteID = "check_athlete_id"
        case seasonID = "check_season_id"
        case fromTeamID = "from_team_id"
        case toTeamID = "to_team_id"
    }
}

private struct InvitationDeliveryParameters: Encodable {
    let organizationID: UUID
    let email: String
    let roles: [OrganizationRole]
    let teamIDs: [UUID]
    let expiresInHours: Int
    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case email, roles
        case teamIDs = "team_ids"
        case expiresInHours = "expires_in_hours"
    }
}

private struct CloneTeamParameters: Encodable {
    let sourceTeamID: UUID
    let targetSeasonID: UUID
    let name: String
    enum CodingKeys: String, CodingKey {
        case sourceTeamID = "source_team_id"
        case targetSeasonID = "target_season_id"
        case name = "cloned_team_name"
    }
}
