import Combine
import Foundation

@MainActor
final class OrganizationViewModel: ObservableObject {
    @Published private(set) var context = OrganizationContext(
        organizations: [],
        memberships: [],
        teams: [],
        seasons: []
    )
    @Published private(set) var members: [OrganizationMembership] = []
    @Published private(set) var teamMemberships:
        [OrganizationTeamMembership] = []
    @Published private(set) var invitations: [OrganizationInvitation] = []
    @Published private(set) var analytics: OrganizationAnalytics?
    @Published var selectedOrganizationID: UUID?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var invitationStatusMessage: String?

    let repository: OrganizationRepository
    private var hasLoaded = false

    init(repository: OrganizationRepository) {
        self.repository = repository
    }

    var selectedOrganization: Organization? {
        context.organizations.first { $0.id == selectedOrganizationID }
    }

    var selectedTeams: [OrganizationTeam] {
        context.teams.filter {
            $0.organizationID == selectedOrganizationID
        }
    }

    var selectedSeasons: [OrganizationSeason] {
        context.seasons.filter {
            $0.organizationID == selectedOrganizationID
        }
    }

    var currentRoles: [OrganizationRole] {
        context.memberships.first {
            $0.organizationID == selectedOrganizationID
        }?.roles ?? []
    }

    var canAdminister: Bool {
        currentRoles.contains(.organizationOwner)
            || currentRoles.contains(.administrator)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func refresh() async {
        await load()
    }

    func selectOrganization(_ id: UUID) async {
        selectedOrganizationID = id
        await loadDetails()
    }

    func createOrganization(name: String) async {
        await perform {
            let id = try await repository.createOrganization(name: name)
            selectedOrganizationID = id
            await AnalyticsService.shared.track(.organizationCreated)
            await load()
        }
    }

    func createTeam(name: String, ageGroup: String) async {
        guard let selectedOrganizationID else { return }
        await perform {
            try await repository.createTeam(
                organizationID: selectedOrganizationID,
                name: name,
                ageGroup: ageGroup
            )
            await load()
        }
    }

    func archiveTeam(_ team: OrganizationTeam) async {
        await perform {
            try await repository.archiveTeam(
                id: team.id,
                archived: !team.isArchived
            )
            await load()
        }
    }

    func createSeason(
        name: String,
        startsOn: Date,
        endsOn: Date
    ) async {
        guard let selectedOrganizationID else { return }
        await perform {
            try await repository.createSeason(
                organizationID: selectedOrganizationID,
                name: name,
                startsOn: startsOn,
                endsOn: endsOn
            )
            await load()
        }
    }

    func archiveSeason(_ season: OrganizationSeason) async {
        await perform {
            try await repository.archiveSeason(
                id: season.id,
                archived: !season.isArchived
            )
            await load()
        }
    }

    func cloneTeam(
        _ team: OrganizationTeam,
        into season: OrganizationSeason,
        named name: String
    ) async {
        await perform {
            try await repository.cloneTeam(
                sourceTeamID: team.id,
                targetSeasonID: season.id,
                name: name
            )
            await load()
        }
    }

    func updateRoles(
        member: OrganizationMembership,
        roles: [OrganizationRole]
    ) async {
        await perform {
            try await repository.updateRoles(
                membershipID: member.id,
                roles: roles
            )
            await loadDetails()
        }
    }

    func assign(
        member: OrganizationMembership,
        team: OrganizationTeam,
        role: OrganizationRole
    ) async {
        guard let selectedOrganizationID else { return }
        let athleteID = teamMemberships.first {
            $0.membershipID == member.id && $0.role == .athlete
        }?.athleteID
        await perform {
            try await repository.assignMember(
                organizationID: selectedOrganizationID,
                teamID: team.id,
                membershipID: member.id,
                role: role,
                athleteID: role == .athlete ? athleteID : nil
            )
            await loadDetails()
        }
    }

    func moveAthlete(
        membership: OrganizationTeamMembership,
        to team: OrganizationTeam,
        season: OrganizationSeason
    ) async {
        guard let organizationID = selectedOrganizationID,
              let athleteID = membership.athleteID else { return }
        await perform {
            try await repository.moveAthlete(
                athleteID: athleteID,
                organizationID: organizationID,
                seasonID: season.id,
                fromTeamID: membership.teamID,
                toTeamID: team.id
            )
            await loadDetails()
        }
    }

    func invite(
        email: String,
        roles: [OrganizationRole],
        teamIDs: [UUID],
        expiresInHours: Int
    ) async {
        guard let selectedOrganizationID else { return }
        await perform {
            try await repository.createInvitation(
                organizationID: selectedOrganizationID,
                email: email,
                roles: roles,
                teamIDs: teamIDs,
                expiresInHours: expiresInHours
            )
            invitationStatusMessage = "Invitation email sent."
            await AnalyticsService.shared.track(.invitationSent)
            await loadDetails()
        }
    }

    func revoke(_ invitation: OrganizationInvitation) async {
        await perform {
            try await repository.revokeInvitation(id: invitation.id)
            await loadDetails()
        }
    }

    func respond(token: String, accept: Bool) async {
        await perform {
            try await repository.respondToInvitation(
                token: token,
                accept: accept
            )
            if accept {
                await AnalyticsService.shared.track(.invitationAccepted)
            }
            await load()
        }
    }

    func transferOwnership(to member: OrganizationMembership) async {
        guard let selectedOrganizationID else { return }
        await perform {
            try await repository.transferOwnership(
                organizationID: selectedOrganizationID,
                newOwnerUserID: member.userID
            )
            await load()
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            context = try await repository.loadContext()
            if selectedOrganizationID == nil
                || !context.organizations.contains(
                    where: { $0.id == selectedOrganizationID }
                ) {
                selectedOrganizationID = context.organizations.first?.id
            }
            await loadDetails()
            hasLoaded = true
        } catch {
            errorMessage = Self.message(error)
        }
        isLoading = false
    }

    private func loadDetails() async {
        guard let selectedOrganizationID else {
            members = []
            invitations = []
            analytics = nil
            return
        }
        do {
            async let loadedMembers = repository.loadMembers(
                organizationID: selectedOrganizationID
            )
            async let loadedTeamMembers = repository.loadTeamMemberships(
                organizationID: selectedOrganizationID
            )
            members = try await loadedMembers
            teamMemberships = try await loadedTeamMembers
            if canAdminister {
                invitations = try await repository.loadInvitations(
                    organizationID: selectedOrganizationID
                )
                analytics = try await repository.analytics(
                    organizationID: selectedOrganizationID,
                    context: context
                )
            } else {
                invitations = []
                analytics = nil
            }
        } catch {
            errorMessage = Self.message(error)
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        errorMessage = nil
        do {
            try await action()
        } catch {
            errorMessage = Self.message(error)
        }
    }

    private static func message(_ error: Error) -> String {
        (error as NSError).domain == NSURLErrorDomain
            ? "You're offline. Cached organization data is shown."
            : error.localizedDescription
    }
}
