import SwiftUI

struct OrganizationDashboardView: View {
    @StateObject private var viewModel: OrganizationViewModel
    @State private var newOrganizationName = ""
    @State private var invitationToken = ""

    init(repository: OrganizationRepository) {
        _viewModel = StateObject(
            wrappedValue: OrganizationViewModel(repository: repository)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Invitation") {
                    TextField(
                        "Invitation code",
                        text: $invitationToken
                    )
                    .textInputAutocapitalization(.never)
                    HStack {
                        Button("Accept") {
                            Task {
                                await viewModel.respond(
                                    token: invitationToken,
                                    accept: true
                                )
                                invitationToken = ""
                            }
                        }
                        Button("Decline") {
                            Task {
                                await viewModel.respond(
                                    token: invitationToken,
                                    accept: false
                                )
                                invitationToken = ""
                            }
                        }
                    }
                    .disabled(invitationToken.isEmpty)
                }

                if viewModel.context.organizations.isEmpty {
                    Section("Create Organization") {
                        TextField(
                            "Organization name",
                            text: $newOrganizationName
                        )
                        Button("Create Organization") {
                            Task {
                                await viewModel.createOrganization(
                                    name: newOrganizationName
                                )
                                newOrganizationName = ""
                            }
                        }
                        .disabled(newOrganizationName.isEmpty)
                    }
                } else {
                    Section("Organization") {
                        Picker(
                            "Current Organization",
                            selection: Binding(
                                get: { viewModel.selectedOrganizationID },
                                set: { id in
                                    guard let id else { return }
                                    Task {
                                        await viewModel.selectOrganization(id)
                                    }
                                }
                            )
                        ) {
                            ForEach(viewModel.context.organizations) {
                                Text($0.name).tag(Optional($0.id))
                            }
                        }
                        Text(
                            viewModel.currentRoles
                                .map(\.title)
                                .joined(separator: ", ")
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    }

                    if let analytics = viewModel.analytics {
                        Section("Organization Analytics") {
                            metric(
                                "Active Athletes",
                                "\(analytics.activeAthletes)"
                            )
                            metric("Active Teams", "\(analytics.activeTeams)")
                            metric(
                                "Coach Activity",
                                "\(analytics.activeCoaches) active staff"
                            )
                            metric(
                                "Testing Completion",
                                "\(Int(analytics.testingCompletion.rounded()))%"
                            )
                            metric(
                                "Workout Compliance",
                                "\(Int(analytics.workoutCompliance.rounded()))%"
                            )
                            metric(
                                "Season Progress",
                                "\(Int(analytics.seasonProgress.rounded()))%"
                            )
                        }
                    }

                    Section("Management") {
                        NavigationLink("Teams") {
                            TeamManagementView(viewModel: viewModel)
                        }
                        NavigationLink("Seasons") {
                            SeasonManagementView(viewModel: viewModel)
                        }
                        NavigationLink("Members") {
                            MemberManagementView(viewModel: viewModel)
                        }
                        if viewModel.canAdminister {
                            NavigationLink("Invite Members") {
                                InviteMembersView(viewModel: viewModel)
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(AppColors.error)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .navigationTitle("Organization")
            .refreshable { await viewModel.refresh() }
            .overlay {
                if viewModel.isLoading
                    && viewModel.context.organizations.isEmpty {
                    LoadingView()
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TeamManagementView: View {
    @ObservedObject var viewModel: OrganizationViewModel
    @State private var name = ""
    @State private var ageGroup = ""

    var body: some View {
        List {
            if viewModel.canAdminister {
                Section("Create Team") {
                    TextField("Team name", text: $name)
                    TextField("Age group", text: $ageGroup)
                    Button("Create Team") {
                        Task {
                            await viewModel.createTeam(
                                name: name,
                                ageGroup: ageGroup
                            )
                            name = ""
                            ageGroup = ""
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }

            Section("Teams") {
                ForEach(viewModel.selectedTeams) { team in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(team.name)
                            Text(
                                team.isArchived
                                    ? "Archived"
                                    : team.ageGroup
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        if viewModel.canAdminister {
                            Button(
                                team.isArchived ? "Restore" : "Archive"
                            ) {
                                Task { await viewModel.archiveTeam(team) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
            }
        }
        .navigationTitle("Team Management")
    }
}

struct SeasonManagementView: View {
    @ObservedObject var viewModel: OrganizationViewModel
    @State private var name = ""
    @State private var startsOn = Date()
    @State private var endsOn = Calendar.current.date(
        byAdding: .month,
        value: 8,
        to: Date()
    ) ?? Date()
    @State private var sourceTeamID: UUID?
    @State private var targetSeasonID: UUID?
    @State private var clonedTeamName = ""

    var body: some View {
        List {
            if viewModel.canAdminister {
                Section("Create Season") {
                    TextField("Season name", text: $name)
                    DatePicker(
                        "Starts",
                        selection: $startsOn,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "Ends",
                        selection: $endsOn,
                        displayedComponents: .date
                    )
                    Button("Create Season") {
                        Task {
                            await viewModel.createSeason(
                                name: name,
                                startsOn: startsOn,
                                endsOn: endsOn
                            )
                            name = ""
                        }
                    }
                    .disabled(name.isEmpty || endsOn < startsOn)
                }

                if !viewModel.selectedTeams.isEmpty,
                   !viewModel.selectedSeasons.isEmpty {
                    Section("Clone Team Into Season") {
                        Picker("Source team", selection: $sourceTeamID) {
                            Text("Select").tag(UUID?.none)
                            ForEach(viewModel.selectedTeams) {
                                Text($0.name).tag(Optional($0.id))
                            }
                        }
                        Picker("Target season", selection: $targetSeasonID) {
                            Text("Select").tag(UUID?.none)
                            ForEach(viewModel.selectedSeasons) {
                                Text($0.name).tag(Optional($0.id))
                            }
                        }
                        TextField("New team name", text: $clonedTeamName)
                        Button("Clone Team") {
                            guard let team = viewModel.selectedTeams.first(
                                where: { $0.id == sourceTeamID }
                            ), let season = viewModel.selectedSeasons.first(
                                where: { $0.id == targetSeasonID }
                            ) else { return }
                            Task {
                                await viewModel.cloneTeam(
                                    team,
                                    into: season,
                                    named: clonedTeamName
                                )
                                clonedTeamName = ""
                            }
                        }
                        .disabled(
                            sourceTeamID == nil
                                || targetSeasonID == nil
                                || clonedTeamName.isEmpty
                        )
                    }
                }
            }

            Section("Seasons") {
                ForEach(viewModel.selectedSeasons) { season in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(season.name)
                            Text(
                                "\(season.startsOn.formatted(date: .abbreviated, time: .omitted)) – \(season.endsOn.formatted(date: .abbreviated, time: .omitted))"
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        if viewModel.canAdminister {
                            Button(
                                season.isArchived ? "Restore" : "Archive"
                            ) {
                                Task { await viewModel.archiveSeason(season) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Season Management")
    }
}

struct MemberManagementView: View {
    @ObservedObject var viewModel: OrganizationViewModel

    var body: some View {
        List(viewModel.members) { member in
            NavigationLink {
                RoleManagementView(
                    viewModel: viewModel,
                    member: member
                )
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(
                        member.displayName.isEmpty
                            ? member.email
                            : member.displayName
                    )
                    .font(AppTypography.headline)
                    Text(member.roles.map(\.title).joined(separator: ", "))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .disabled(!viewModel.canAdminister)
        }
        .navigationTitle("Member Management")
    }
}

struct RoleManagementView: View {
    @ObservedObject var viewModel: OrganizationViewModel
    let member: OrganizationMembership
    @State private var selectedRoles: Set<OrganizationRole>

    init(
        viewModel: OrganizationViewModel,
        member: OrganizationMembership
    ) {
        self.viewModel = viewModel
        self.member = member
        _selectedRoles = State(initialValue: Set(member.roles))
    }

    var body: some View {
        List {
            Section("Organization Roles") {
                ForEach(
                    OrganizationRole.allCases.filter {
                        $0 != .organizationOwner
                    }
                ) { role in
                    Button {
                        if selectedRoles.contains(role) {
                            selectedRoles.remove(role)
                        } else {
                            selectedRoles.insert(role)
                        }
                    } label: {
                        HStack {
                            Text(role.title)
                            Spacer()
                            if selectedRoles.contains(role) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .accessibilityValue(
                        selectedRoles.contains(role)
                            ? "Selected"
                            : "Not selected"
                    )
                }
            }

            Button("Save Roles") {
                Task {
                    await viewModel.updateRoles(
                        member: member,
                        roles: Array(selectedRoles)
                    )
                }
            }
            .disabled(selectedRoles.isEmpty)

            if viewModel.currentRoles.contains(.organizationOwner),
               !member.roles.contains(.organizationOwner) {
                Button("Transfer Organization Ownership") {
                    Task {
                        await viewModel.transferOwnership(to: member)
                    }
                }
                .foregroundStyle(AppColors.warning)
            }
        }
        .navigationTitle("Role Management")
    }
}

struct InviteMembersView: View {
    @ObservedObject var viewModel: OrganizationViewModel
    @State private var email = ""
    @State private var roles: Set<OrganizationRole> = []
    @State private var teamIDs: Set<UUID> = []
    @State private var expiration = 168

    var body: some View {
        Form {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)

            Section("Roles") {
                ForEach(
                    OrganizationRole.allCases.filter {
                        $0 != .organizationOwner
                    }
                ) { role in
                    selectionButton(
                        role.title,
                        selected: roles.contains(role)
                    ) {
                        toggle(role, in: &roles)
                    }
                }
            }

            Section("Teams") {
                ForEach(viewModel.selectedTeams.filter { !$0.isArchived }) {
                    team in
                    selectionButton(
                        team.name,
                        selected: teamIDs.contains(team.id)
                    ) {
                        toggle(team.id, in: &teamIDs)
                    }
                }
            }

            Picker("Expires", selection: $expiration) {
                Text("24 hours").tag(24)
                Text("7 days").tag(168)
                Text("30 days").tag(720)
            }

            Button("Create Email Invitation") {
                Task {
                    await viewModel.invite(
                        email: email,
                        roles: Array(roles),
                        teamIDs: Array(teamIDs),
                        expiresInHours: expiration
                    )
                }
            }
            .disabled(!email.contains("@") || roles.isEmpty)

            if let message = viewModel.invitationStatusMessage {
                Section("Delivery") {
                    Text(message)
                        .foregroundStyle(AppColors.success)
                        .accessibilityLabel("Success: \(message)")
                }
            }

            Section("Invitations") {
                ForEach(viewModel.invitations) { invitation in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(invitation.email)
                            Text(invitation.status.capitalized)
                                .font(AppTypography.caption)
                        }
                        Spacer()
                        if invitation.status == "pending" {
                            Button("Revoke") {
                                Task {
                                    await viewModel.revoke(invitation)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Invite Members")
    }

    private func selectionButton(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if selected { Image(systemName: "checkmark") }
            }
        }
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func toggle<Value: Hashable>(
        _ value: Value,
        in set: inout Set<Value>
    ) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

struct AthleteTeamSwitcherView: View {
    let context: OrganizationContext
    @State private var selectedTeamID: UUID?

    var body: some View {
        List {
            Section("Current and Previous Seasons") {
                ForEach(context.seasons) { season in
                    VStack(alignment: .leading) {
                        Text(season.name)
                        Text(season.isArchived ? "Previous" : "Current")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            Section("Teams") {
                Picker("Active Team", selection: $selectedTeamID) {
                    Text("Select Team").tag(Optional<UUID>.none)
                    ForEach(context.teams.filter { !$0.isArchived }) {
                        Text($0.name).tag(Optional($0.id))
                    }
                }
            }
        }
        .navigationTitle("My Teams")
    }
}

struct ParentHomeView: View {
    let organizationRepository: OrganizationRepository
    let testingRepository: TestingRepository?
    let athleteService: AthleteService
    @State private var activities: [ParentAthleteActivity] = []
    @State private var errorMessage: String?

    var body: some View {
        TabView {
            NavigationStack {
                List {
                    ForEach(activities) { activity in
                        Section(activity.athleteName) {
                            row(
                                "Workouts Completed",
                                "\(activity.workoutsCompleted)"
                            )
                            row(
                                "Testing Sessions",
                                "\(activity.testsCompleted)"
                            )
                            row(
                                "Attendance",
                                "\(Int(activity.attendancePercent.rounded()))%"
                            )
                            row("Editing", "Read-only")
                        }
                    }
                }
                .navigationTitle("Athlete Progress")
                .refreshable { await load() }
                .overlay {
                    if activities.isEmpty, let errorMessage {
                        ContentUnavailableView(
                            "Progress Unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                    }
                }
            }
            .tabItem {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
            }

            if let testingRepository {
                TestingDashboardView(
                    role: .parent,
                    repository: testingRepository,
                    athleteService: athleteService
                )
                .tabItem {
                    Label("Testing", systemImage: "stopwatch")
                }
            }
        }
        .task { await load() }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            activities = try await organizationRepository.loadParentActivity()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
