#if DEBUG
import SwiftUI

enum DeveloperSessionRole: String, CaseIterable, Identifiable {
    case athlete
    case coach
    case parent
    case forgeAdmin

    var id: Self { self }

    var title: String {
        switch self {
        case .athlete: "Athlete"
        case .coach: "Coach"
        case .parent: "Parent"
        case .forgeAdmin: "Forge Admin"
        }
    }

    var symbol: String {
        switch self {
        case .athlete: "figure.hockey"
        case .coach: "person.3.fill"
        case .parent: "figure.2.and.child.holdinghands"
        case .forgeAdmin: "wrench.and.screwdriver.fill"
        }
    }
}

struct DeveloperSession: Identifiable {
    let id: UUID
    let role: DeveloperSessionRole
    let displayName: String
    let email: String
    let organizationRoles: [OrganizationRole]
}

private struct DeveloperWorkoutSession {
    let id: UUID
    let workoutID: UUID
    let startedAt: Date
    var sets: [WorkoutSetLog]
}

@MainActor
final class DeveloperModeStore: ObservableObject {
    @Published var selectedSession: DeveloperSession?
    @Published private var athlete: Athlete
    @Published private var athletes: [Athlete]
    @Published private var mutablePrograms: [TrainingProgram]
    @Published private var protocols: [TestingProtocol]
    @Published private var testSessions: [TestingSession]
    @Published private var context: OrganizationContext
    @Published private var members: [OrganizationMembership]
    @Published private var teamMembers: [OrganizationTeamMembership]
    @Published private var invitations: [OrganizationInvitation]

    let sessions: [DeveloperSession]
    let organization: Organization
    let team: OrganizationTeam
    let workouts: [Workout]
    let exercises: [Exercise]

    private var workoutSessions: [UUID: DeveloperWorkoutSession] = [:]
    private var assignments: [UUID: UUID] = [:]

    init() {
        let ids = DeveloperIDs()
        organization = Organization(
            id: ids.organization,
            name: "Forge Hockey Academy",
            slug: "forge-hockey-academy",
            ownerUserID: ids.owner
        )
        team = OrganizationTeam(
            id: ids.team,
            organizationID: ids.organization,
            name: "U18 Forge",
            ageGroup: "U18",
            isArchived: false
        )

        let primaryAthlete = Self.makeAthlete(
            id: ids.athlete,
            userID: ids.athleteUser,
            firstName: "Yegor",
            lastName: "Hambaryan",
            position: .center,
            team: "U18 Forge",
            graduationYear: 2027
        )
        let secondAthlete = Self.makeAthlete(
            id: ids.secondAthlete,
            userID: ids.secondAthleteUser,
            firstName: "Maya",
            lastName: "Chen",
            position: .defense,
            team: "U18 Forge",
            graduationYear: 2026
        )
        let thirdAthlete = Self.makeAthlete(
            id: ids.thirdAthlete,
            userID: ids.thirdAthleteUser,
            firstName: "Liam",
            lastName: "Brooks",
            position: .goalie,
            team: "U18 Forge",
            graduationYear: 2027
        )
        athlete = primaryAthlete
        athletes = [primaryAthlete, secondAthlete, thirdAthlete]

        let squat = Self.makeExercise(
            id: ids.squat,
            name: "Back Squat",
            category: .strength,
            hockeyCategory: .skatingStrength,
            muscles: [.quadriceps, .glutes],
            equipment: [.barbell]
        )
        let bounds = Self.makeExercise(
            id: ids.bounds,
            name: "Lateral Bounds",
            category: .plyometrics,
            hockeyCategory: .lateralPower,
            muscles: [.glutes, .adductors],
            equipment: [.bodyweight]
        )
        let deadlift = Self.makeExercise(
            id: ids.deadlift,
            name: "Trap Bar Deadlift",
            category: .strength,
            hockeyCategory: .posteriorChain,
            muscles: [.hamstrings, .glutes],
            equipment: [.trapBar]
        )
        exercises = [squat, bounds, deadlift]

        let prescriptions = [
            Self.prescription(squat, sets: 4, reps: "5", order: 0),
            Self.prescription(bounds, sets: 3, reps: "6 each side", order: 1),
            Self.prescription(deadlift, sets: 3, reps: "6", order: 2)
        ]
        workouts = [
            Workout(
                id: ids.workout,
                title: "Lower Body Power",
                description: "Skating-strength and lateral-power development.",
                estimatedDurationMinutes: 55,
                scheduledDate: Date(),
                status: .scheduled,
                exercises: prescriptions,
                assignmentID: ids.assignment
            ),
            Workout(
                id: ids.upcomingWorkout,
                title: "Upper Body Strength",
                description: "Durable strength for contact and puck control.",
                estimatedDurationMinutes: 45,
                scheduledDate: Calendar.current.date(
                    byAdding: .day,
                    value: 2,
                    to: Date()
                ) ?? Date(),
                status: .scheduled,
                exercises: [Self.prescription(squat, sets: 3, reps: "8", order: 0)],
                assignmentID: ids.assignment
            ),
            Workout(
                id: ids.completedWorkout,
                title: "Acceleration",
                description: "First-step acceleration and landing mechanics.",
                estimatedDurationMinutes: 40,
                scheduledDate: Calendar.current.date(
                    byAdding: .day,
                    value: -3,
                    to: Date()
                ) ?? Date(),
                status: .completed,
                exercises: [Self.prescription(bounds, sets: 4, reps: "5", order: 0)],
                assignmentID: ids.assignment
            )
        ]

        let programExercises = prescriptions.enumerated().map { index, item in
            ProgramExercise(
                id: item.id,
                exerciseID: item.exerciseID,
                name: item.name,
                sets: item.sets,
                repsMin: Int(item.reps.prefix { $0.isNumber }) ?? 5,
                repsMax: Int(item.reps.prefix { $0.isNumber }) ?? 5,
                restSeconds: item.restSeconds,
                tempo: "Controlled",
                notes: item.coachNotes,
                coachCues: "Move with intent.",
                sortOrder: index
            )
        }
        let programWorkout = ProgramWorkout(
            id: ids.programWorkout,
            name: "Lower Body Power",
            description: "Skating-strength and lateral-power development.",
            dayNumber: 1,
            estimatedDurationMinutes: 55,
            sortOrder: 0,
            exercises: programExercises
        )
        mutablePrograms = [
            TrainingProgram(
                id: ids.program,
                name: "Preseason Performance",
                description: "Four-week hockey performance block.",
                status: .published,
                durationWeeks: 4,
                weeks: [
                    TrainingProgramWeek(
                        id: ids.programWeek,
                        weekNumber: 1,
                        name: "Foundation",
                        focus: "Movement quality and force production",
                        workouts: [programWorkout]
                    )
                ]
            )
        ]
        assignments[ids.athlete] = ids.assignment

        let verticalJump = TestingMetric(
            id: ids.verticalJump,
            key: "vertical_jump",
            name: "Vertical Jump",
            category: .lowerBody,
            unit: "in",
            instructions: "Record the best of three attempts."
        )
        let sprint = TestingMetric(
            id: ids.sprint,
            key: "sprint_10m",
            name: "10 m Sprint",
            category: .speed,
            unit: "s",
            direction: .lower,
            sortOrder: 1,
            instructions: "Start from a two-point stance."
        )
        let protocolValue = TestingProtocol(
            id: ids.protocolID,
            coachUserID: ids.coach,
            name: "Hockey Performance Combine",
            description: "Core speed and power testing.",
            status: .active,
            allowsAthleteEntry: true,
            metrics: [verticalJump, sprint]
        )
        protocols = [protocolValue]
        let pastSessionID = ids.completedTest
        testSessions = [
            TestingSession(
                id: ids.upcomingTest,
                protocolID: protocolValue.id,
                athleteID: ids.athlete,
                protocolName: protocolValue.name,
                athleteName: "Yegor Hambaryan",
                athletePosition: "Center",
                scheduledAt: Calendar.current.date(
                    byAdding: .day,
                    value: 5,
                    to: Date()
                ) ?? Date(),
                completedAt: nil,
                seasonLabel: "2026–27",
                location: "Forge Performance Lab",
                status: .scheduled,
                allowsAthleteEntry: true,
                metrics: protocolValue.metrics,
                results: []
            ),
            TestingSession(
                id: pastSessionID,
                protocolID: protocolValue.id,
                athleteID: ids.athlete,
                protocolName: protocolValue.name,
                athleteName: "Yegor Hambaryan",
                athletePosition: "Center",
                scheduledAt: Calendar.current.date(
                    byAdding: .month,
                    value: -2,
                    to: Date()
                ) ?? Date(),
                completedAt: Calendar.current.date(
                    byAdding: .month,
                    value: -2,
                    to: Date()
                ),
                seasonLabel: "2026–27",
                location: "Forge Performance Lab",
                status: .completed,
                allowsAthleteEntry: true,
                metrics: protocolValue.metrics,
                results: [
                    Self.testingResult(
                        sessionID: pastSessionID,
                        athleteID: ids.athlete,
                        metric: verticalJump,
                        value: 25.5
                    ),
                    Self.testingResult(
                        sessionID: pastSessionID,
                        athleteID: ids.athlete,
                        metric: sprint,
                        value: 1.78
                    )
                ]
            )
        ]

        let initialMembers = [
            OrganizationMembership(
                id: ids.ownerMembership,
                organizationID: ids.organization,
                userID: ids.owner,
                displayName: "Alex Morgan",
                email: "coach@developer.invalid",
                roles: [.organizationOwner, .headCoach],
                status: "active"
            ),
            OrganizationMembership(
                id: ids.athleteMembership,
                organizationID: ids.organization,
                userID: ids.athleteUser,
                displayName: "Yegor Hambaryan",
                email: "athlete@developer.invalid",
                roles: [.athlete],
                status: "active"
            ),
            OrganizationMembership(
                id: ids.parentMembership,
                organizationID: ids.organization,
                userID: ids.parent,
                displayName: "Jordan Hambaryan",
                email: "parent@developer.invalid",
                roles: [.parent],
                status: "active"
            )
        ]
        members = initialMembers
        teamMembers = [
            OrganizationTeamMembership(
                id: ids.teamMembership,
                organizationID: ids.organization,
                teamID: ids.team,
                membershipID: ids.athleteMembership,
                role: .athlete,
                athleteID: ids.athlete
            )
        ]
        invitations = []
        context = OrganizationContext(
            organizations: [organization],
            memberships: initialMembers,
            teams: [team],
            seasons: [
                OrganizationSeason(
                    id: ids.season,
                    organizationID: ids.organization,
                    name: "2026–27",
                    startsOn: Calendar.current.date(
                        byAdding: .month,
                        value: -1,
                        to: Date()
                    ) ?? Date(),
                    endsOn: Calendar.current.date(
                        byAdding: .month,
                        value: 8,
                        to: Date()
                    ) ?? Date(),
                    isArchived: false
                )
            ]
        )

        sessions = [
            DeveloperSession(
                id: ids.athleteUser,
                role: .athlete,
                displayName: "Yegor Hambaryan",
                email: "athlete@developer.invalid",
                organizationRoles: [.athlete]
            ),
            DeveloperSession(
                id: ids.coach,
                role: .coach,
                displayName: "Alex Morgan",
                email: "coach@developer.invalid",
                organizationRoles: [.headCoach, .strengthCoach]
            ),
            DeveloperSession(
                id: ids.parent,
                role: .parent,
                displayName: "Jordan Hambaryan",
                email: "parent@developer.invalid",
                organizationRoles: [.parent]
            ),
            DeveloperSession(
                id: ids.admin,
                role: .forgeAdmin,
                displayName: "Forge Platform Admin",
                email: "admin@developer.invalid",
                organizationRoles: [.organizationOwner, .administrator]
            )
        ]
    }

    func resetSession() {
        selectedSession = nil
    }

    func currentAthlete() -> Athlete { athlete }
    func allAthletes() -> [Athlete] { athletes }
    func currentUserID() -> UUID { selectedSession?.id ?? athlete.userID }
    func exerciseLibrary() -> [Exercise] { exercises }
    func trainingPlan() -> TrainingPlan { TrainingPlan(workouts: workouts) }

    func updateAthlete(_ updated: Athlete) {
        athlete = updated
        if let index = athletes.firstIndex(where: { $0.id == updated.id }) {
            athletes[index] = updated
        }
    }

    func restoreWorkoutSession(
        workoutID: UUID
    ) -> RestoredWorkoutSession? {
        guard let value = workoutSessions[workoutID] else { return nil }
        return RestoredWorkoutSession(
            id: value.id,
            startedAt: value.startedAt,
            sets: value.sets
        )
    }

    func startWorkoutSession(workoutID: UUID) -> RestoredWorkoutSession {
        if let existing = restoreWorkoutSession(workoutID: workoutID) {
            return existing
        }
        let value = DeveloperWorkoutSession(
            id: UUID(),
            workoutID: workoutID,
            startedAt: Date(),
            sets: []
        )
        workoutSessions[workoutID] = value
        return RestoredWorkoutSession(
            id: value.id,
            startedAt: value.startedAt,
            sets: []
        )
    }

    func saveWorkoutSet(_ set: WorkoutSetLog, sessionID: UUID) {
        guard let workoutID = workoutSessions.first(where: {
            $0.value.id == sessionID
        })?.key else { return }
        workoutSessions[workoutID]?.sets.removeAll { $0.id == set.id }
        workoutSessions[workoutID]?.sets.append(set)
    }

    func finishWorkoutSession(
        id: UUID,
        startedAt: Date,
        sets: [WorkoutSetLog]
    ) -> WorkoutSessionSummary {
        workoutSessions = workoutSessions.filter { $0.value.id != id }
        let reps = sets.reduce(0) { $0 + $1.reps }
        return WorkoutSessionSummary(
            totalVolume: sets.reduce(0) {
                $0 + $1.weight * Double($1.reps)
            },
            totalSets: sets.count,
            totalReps: reps,
            durationSeconds: max(
                1,
                Int(Date().timeIntervalSince(startedAt))
            ),
            personalRecords: sets.isEmpty
                ? []
                : ["Back Squat training volume"]
        )
    }

    func previousWorkoutValue(
        exerciseID: UUID
    ) -> PreviousWorkoutValue? {
        guard exercises.contains(where: { $0.id == exerciseID }) else {
            return nil
        }
        return PreviousWorkoutValue(weight: 185, reps: 5, rpe: 8)
    }

    func programs() -> [TrainingProgram] { mutablePrograms }

    func program(id: UUID) throws -> TrainingProgram {
        guard let value = mutablePrograms.first(where: { $0.id == id }) else {
            throw TrainingRepositoryError.invalidTrainingData
        }
        return value
    }

    func createProgram() -> TrainingProgram {
        let value = TrainingProgram(
            id: UUID(),
            name: "Untitled Program",
            description: "",
            status: .draft,
            durationWeeks: 1,
            weeks: []
        )
        mutablePrograms.insert(value, at: 0)
        return value
    }

    func updateProgram(_ value: TrainingProgram) {
        replaceProgram(value)
    }

    func setProgramStatus(
        _ status: TrainingProgramStatus,
        program: TrainingProgram
    ) throws {
        if status == .published,
           program.weeks.flatMap(\.workouts).flatMap(\.exercises).isEmpty {
            throw ProgramRepositoryError.emptyProgram
        }
        var updated = program
        updated.status = status
        replaceProgram(updated)
    }

    func deleteProgram(id: UUID) {
        mutablePrograms.removeAll { $0.id == id }
    }

    func duplicateProgram(_ source: TrainingProgram) throws -> UUID {
        let original = try program(id: source.id)
        let id = UUID()
        var copy = original
        copy = TrainingProgram(
            id: id,
            name: "\(copy.name) Copy",
            description: copy.description,
            status: .draft,
            durationWeeks: copy.durationWeeks,
            weeks: copy.weeks
        )
        mutablePrograms.insert(copy, at: 0)
        return id
    }

    func addProgramWeek(
        programID: UUID,
        number: Int,
        name: String?
    ) throws -> TrainingProgramWeek {
        var value = try program(id: programID)
        let week = TrainingProgramWeek(
            id: UUID(),
            weekNumber: number,
            name: name ?? "Week \(number)",
            focus: "",
            workouts: []
        )
        value.weeks.append(week)
        value.durationWeeks = max(1, value.weeks.count)
        replaceProgram(value)
        return week
    }

    func updateProgramWeek(_ week: TrainingProgramWeek) {
        mutateWeek(id: week.id) { $0 = week }
    }

    func reorderProgramWeeks(_ weeks: [TrainingProgramWeek]) {
        guard let index = mutablePrograms.firstIndex(where: { program in
            program.weeks.contains { $0.id == weeks.first?.id }
        }) else { return }
        mutablePrograms[index].weeks = weeks.enumerated().map { offset, week in
            var value = week
            value.weekNumber = offset + 1
            return value
        }
    }

    func deleteProgramWeek(id: UUID) {
        for index in mutablePrograms.indices {
            mutablePrograms[index].weeks.removeAll { $0.id == id }
        }
    }

    func addProgramWorkout(
        weekID: UUID,
        dayNumber: Int,
        sortOrder: Int,
        name: String
    ) throws -> ProgramWorkout {
        let workout = ProgramWorkout(
            id: UUID(),
            name: name,
            description: "",
            dayNumber: dayNumber,
            estimatedDurationMinutes: 45,
            sortOrder: sortOrder,
            exercises: []
        )
        guard mutateWeek(id: weekID, mutation: {
            $0.workouts.append(workout)
        }) else {
            throw TrainingRepositoryError.invalidTrainingData
        }
        return workout
    }

    func updateProgramWorkout(_ workout: ProgramWorkout) {
        mutateWorkout(id: workout.id) { $0 = workout }
    }

    func reorderProgramWorkouts(_ workouts: [ProgramWorkout]) {
        guard let first = workouts.first else { return }
        for programIndex in mutablePrograms.indices {
            for weekIndex in mutablePrograms[programIndex].weeks.indices
            where mutablePrograms[programIndex].weeks[weekIndex].workouts
                .contains(where: { $0.id == first.id }) {
                mutablePrograms[programIndex].weeks[weekIndex].workouts =
                    workouts.enumerated().map { index, workout in
                        var value = workout
                        value.sortOrder = index
                        return value
                    }
            }
        }
    }

    func deleteProgramWorkout(id: UUID) {
        for programIndex in mutablePrograms.indices {
            for weekIndex in mutablePrograms[programIndex].weeks.indices {
                mutablePrograms[programIndex].weeks[weekIndex].workouts
                    .removeAll { $0.id == id }
            }
        }
    }

    func programExerciseChoices() -> [ProgramExerciseChoice] {
        exercises.map {
            ProgramExerciseChoice(
                id: $0.id,
                name: $0.name,
                category: $0.category.rawValue,
                difficulty: $0.difficulty.rawValue
            )
        }
    }

    func addProgramExercise(
        workoutID: UUID,
        exerciseID: UUID,
        order: Int,
        values: ProgramExercise?
    ) throws -> ProgramExercise {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }) else {
            throw TrainingRepositoryError.invalidTrainingData
        }
        let value = ProgramExercise(
            id: UUID(),
            exerciseID: exerciseID,
            name: exercise.name,
            sets: values?.sets ?? 3,
            repsMin: values?.repsMin ?? 8,
            repsMax: values?.repsMax ?? 8,
            restSeconds: values?.restSeconds ?? 60,
            tempo: values?.tempo ?? "",
            notes: values?.notes ?? "",
            coachCues: values?.coachCues ?? "",
            sortOrder: order
        )
        guard mutateWorkout(id: workoutID, mutation: {
            $0.exercises.append(value)
        }) else {
            throw TrainingRepositoryError.invalidTrainingData
        }
        return value
    }

    func updateProgramExercise(_ exercise: ProgramExercise) {
        mutateExercise(id: exercise.id) { $0 = exercise }
    }

    func reorderProgramExercises(_ exercises: [ProgramExercise]) {
        guard let first = exercises.first else { return }
        for programIndex in mutablePrograms.indices {
            for weekIndex in mutablePrograms[programIndex].weeks.indices {
                for workoutIndex in mutablePrograms[programIndex]
                    .weeks[weekIndex].workouts.indices
                where mutablePrograms[programIndex].weeks[weekIndex]
                    .workouts[workoutIndex].exercises
                    .contains(where: { $0.id == first.id }) {
                    mutablePrograms[programIndex].weeks[weekIndex]
                        .workouts[workoutIndex].exercises =
                        exercises.enumerated().map { index, exercise in
                            var value = exercise
                            value.sortOrder = index
                            return value
                        }
                }
            }
        }
    }

    func deleteProgramExercise(id: UUID) {
        for programIndex in mutablePrograms.indices {
            for weekIndex in mutablePrograms[programIndex].weeks.indices {
                for workoutIndex in mutablePrograms[programIndex]
                    .weeks[weekIndex].workouts.indices {
                    mutablePrograms[programIndex].weeks[weekIndex]
                        .workouts[workoutIndex].exercises
                        .removeAll { $0.id == id }
                }
            }
        }
    }

    func assignableAthletes(programID: UUID) -> [ProgramAthlete] {
        athletes.map {
            ProgramAthlete(
                id: $0.id,
                name: "\($0.firstName) \($0.lastName)",
                team: $0.team,
                position: $0.position.rawValue,
                graduationYear: $0.graduationYear,
                assignmentID: assignments[$0.id]
            )
        }
    }

    func assignAthlete(
        athleteID: UUID,
        program: TrainingProgram
    ) throws {
        guard program.status == .published else {
            throw ProgramRepositoryError.unpublishedProgram
        }
        guard assignments[athleteID] == nil else {
            throw ProgramRepositoryError.duplicateAssignment
        }
        assignments[athleteID] = UUID()
    }

    func removeAssignment(id: UUID) {
        assignments = assignments.filter { $0.value != id }
    }

    func testingProtocols() -> [TestingProtocol] { protocols }
    func testingSessions() -> [TestingSession] { testSessions }

    func createTestingProtocol(
        name: String,
        description: String,
        allowsAthleteEntry: Bool,
        metrics: [TestingMetric]
    ) throws -> TestingProtocol {
        guard !name.isEmpty, !metrics.isEmpty else {
            throw TestingRepositoryError.invalidProtocol
        }
        let value = TestingProtocol(
            coachUserID: currentUserID(),
            name: name,
            description: description,
            allowsAthleteEntry: allowsAthleteEntry,
            metrics: metrics
        )
        protocols.insert(value, at: 0)
        return value
    }

    func updateTestingProtocol(_ value: TestingProtocol) throws {
        guard !value.name.isEmpty, !value.metrics.isEmpty else {
            throw TestingRepositoryError.invalidProtocol
        }
        protocols.removeAll { $0.id == value.id }
        protocols.insert(value, at: 0)
    }

    func duplicateTestingProtocol(
        _ source: TestingProtocol
    ) -> TestingProtocol {
        let copy = TestingProtocol(
            coachUserID: currentUserID(),
            parentProtocolID: source.id,
            name: "\(source.name) Copy",
            description: source.description,
            version: source.version + 1,
            status: .draft,
            allowsAthleteEntry: source.allowsAthleteEntry,
            metrics: source.metrics
        )
        protocols.insert(copy, at: 0)
        return copy
    }

    func scheduleTesting(
        protocolID: UUID,
        athleteIDs: [UUID],
        date: Date,
        season: String,
        location: String
    ) {
        guard let value = protocols.first(where: { $0.id == protocolID }) else {
            return
        }
        for athleteID in athleteIDs {
            guard let athlete = athletes.first(where: { $0.id == athleteID }) else {
                continue
            }
            testSessions.insert(
                TestingSession(
                    id: UUID(),
                    protocolID: value.id,
                    athleteID: athlete.id,
                    protocolName: value.name,
                    athleteName: "\(athlete.firstName) \(athlete.lastName)",
                    athletePosition: athlete.position.rawValue,
                    scheduledAt: date,
                    completedAt: nil,
                    seasonLabel: season,
                    location: location,
                    status: .scheduled,
                    allowsAthleteEntry: value.allowsAthleteEntry,
                    metrics: value.metrics,
                    results: []
                ),
                at: 0
            )
        }
    }

    func recordTestingResult(
        session: TestingSession,
        metric: TestingMetric,
        value: Double,
        notes: String,
        source: TestingResultSource
    ) throws -> TestingResult {
        guard value.isFinite else {
            throw TestingRepositoryError.invalidResult
        }
        let result = Self.testingResult(
            sessionID: session.id,
            athleteID: session.athleteID,
            metric: metric,
            value: value,
            notes: notes,
            source: source
        )
        if let index = testSessions.firstIndex(where: { $0.id == session.id }) {
            testSessions[index].results.removeAll {
                $0.metricID == metric.id
            }
            testSessions[index].results.append(result)
        }
        return result
    }

    func completeTestingSession(id: UUID) {
        guard let index = testSessions.firstIndex(where: { $0.id == id }) else {
            return
        }
        testSessions[index].status = .completed
        testSessions[index].completedAt = Date()
    }

    func organizationContext() -> OrganizationContext { context }

    func createOrganization(name: String) throws -> UUID {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw OrganizationRepositoryError.invalidName
        }
        return organization.id
    }

    func createTeam(
        organizationID: UUID,
        name: String,
        ageGroup: String
    ) throws {
        guard !name.isEmpty else {
            throw OrganizationRepositoryError.invalidName
        }
        context = OrganizationContext(
            organizations: context.organizations,
            memberships: context.memberships,
            teams: context.teams + [
                OrganizationTeam(
                    id: UUID(),
                    organizationID: organizationID,
                    name: name,
                    ageGroup: ageGroup,
                    isArchived: false
                )
            ],
            seasons: context.seasons
        )
    }

    func archiveTeam(id: UUID, archived: Bool) {
        var teams = context.teams
        guard let index = teams.firstIndex(where: { $0.id == id }) else {
            return
        }
        teams[index].isArchived = archived
        replaceContext(teams: teams)
    }

    func createSeason(
        organizationID: UUID,
        name: String,
        startsOn: Date,
        endsOn: Date
    ) throws {
        guard !name.isEmpty, endsOn >= startsOn else {
            throw OrganizationRepositoryError.invalidName
        }
        var seasons = context.seasons
        seasons.append(
            OrganizationSeason(
                id: UUID(),
                organizationID: organizationID,
                name: name,
                startsOn: startsOn,
                endsOn: endsOn,
                isArchived: false
            )
        )
        replaceContext(seasons: seasons)
    }

    func archiveSeason(id: UUID, archived: Bool) {
        var seasons = context.seasons
        guard let index = seasons.firstIndex(where: { $0.id == id }) else {
            return
        }
        seasons[index].isArchived = archived
        replaceContext(seasons: seasons)
    }

    func cloneTeam(
        sourceTeamID: UUID,
        targetSeasonID: UUID,
        name: String
    ) throws {
        guard context.teams.contains(where: { $0.id == sourceTeamID }),
              context.seasons.contains(where: { $0.id == targetSeasonID }) else {
            throw OrganizationRepositoryError.unavailable
        }
        try createTeam(
            organizationID: organization.id,
            name: name,
            ageGroup: team.ageGroup
        )
    }

    func organizationMembers(
        organizationID: UUID
    ) -> [OrganizationMembership] {
        members.filter { $0.organizationID == organizationID }
    }

    func updateMemberRoles(
        membershipID: UUID,
        roles: [OrganizationRole]
    ) throws {
        guard !roles.isEmpty,
              let index = members.firstIndex(where: {
                  $0.id == membershipID
              }) else {
            throw OrganizationRepositoryError.invalidInvitation
        }
        members[index].roles = roles
    }

    func teamMemberships(
        organizationID: UUID
    ) -> [OrganizationTeamMembership] {
        teamMembers.filter { $0.organizationID == organizationID }
    }

    func assignMember(
        organizationID: UUID,
        teamID: UUID,
        membershipID: UUID,
        role: OrganizationRole,
        athleteID: UUID?
    ) {
        teamMembers.removeAll {
            $0.teamID == teamID && $0.membershipID == membershipID
        }
        teamMembers.append(
            OrganizationTeamMembership(
                id: UUID(),
                organizationID: organizationID,
                teamID: teamID,
                membershipID: membershipID,
                role: role,
                athleteID: athleteID
            )
        )
    }

    func moveAthlete(
        athleteID: UUID,
        organizationID: UUID,
        seasonID: UUID,
        fromTeamID: UUID?,
        toTeamID: UUID
    ) throws {
        guard fromTeamID != nil,
              context.seasons.contains(where: { $0.id == seasonID }),
              context.teams.contains(where: { $0.id == toTeamID }) else {
            throw OrganizationRepositoryError.invalidInvitation
        }
        teamMembers.removeAll { $0.athleteID == athleteID }
        if let membership = members.first(where: {
            $0.userID == athlete.userID
        }) {
            assignMember(
                organizationID: organizationID,
                teamID: toTeamID,
                membershipID: membership.id,
                role: .athlete,
                athleteID: athleteID
            )
        }
    }

    func createInvitation(
        organizationID: UUID,
        email: String,
        roles: [OrganizationRole],
        expiresInHours: Int
    ) throws {
        guard email.contains("@"), !roles.isEmpty else {
            throw OrganizationRepositoryError.invalidInvitation
        }
        invitations.insert(
            OrganizationInvitation(
                id: UUID(),
                organizationID: organizationID,
                email: email.lowercased(),
                roles: roles,
                status: "pending",
                expiresAt: Date().addingTimeInterval(
                    Double(expiresInHours) * 3_600
                )
            ),
            at: 0
        )
    }

    func organizationInvitations(
        organizationID: UUID
    ) -> [OrganizationInvitation] {
        invitations.filter { $0.organizationID == organizationID }
    }

    func revokeInvitation(id: UUID) {
        guard let index = invitations.firstIndex(where: { $0.id == id }) else {
            return
        }
        let value = invitations[index]
        invitations[index] = OrganizationInvitation(
            id: value.id,
            organizationID: value.organizationID,
            email: value.email,
            roles: value.roles,
            status: "revoked",
            expiresAt: value.expiresAt
        )
    }

    func transferOwnership(
        organizationID: UUID,
        newOwnerUserID: UUID
    ) {
        guard organizationID == organization.id else { return }
        for index in members.indices {
            members[index].roles.removeAll { $0 == .organizationOwner }
            if members[index].userID == newOwnerUserID {
                members[index].roles.append(.organizationOwner)
            }
        }
    }

    func organizationAnalytics(
        organizationID: UUID
    ) -> OrganizationAnalytics {
        OrganizationAnalytics(
            activeAthletes: athletes.count,
            activeTeams: context.teams.filter { !$0.isArchived }.count,
            activeCoaches: members.filter {
                $0.roles.contains(where: \.isStaff)
            }.count,
            testingCompletion: 78,
            workoutCompliance: 86,
            seasonProgress: 32
        )
    }

    func parentActivity() -> [ParentAthleteActivity] {
        [
            ParentAthleteActivity(
                id: athlete.id,
                athleteName: "\(athlete.firstName) \(athlete.lastName)",
                workoutsCompleted: 12,
                testsCompleted: 2,
                attendancePercent: 92
            )
        ]
    }

    private func replaceProgram(_ value: TrainingProgram) {
        mutablePrograms.removeAll { $0.id == value.id }
        mutablePrograms.insert(value, at: 0)
    }

    @discardableResult
    private func mutateWeek(
        id: UUID,
        mutation: (inout TrainingProgramWeek) -> Void
    ) -> Bool {
        for programIndex in mutablePrograms.indices {
            if let weekIndex = mutablePrograms[programIndex].weeks.firstIndex(
                where: { $0.id == id }
            ) {
                mutation(&mutablePrograms[programIndex].weeks[weekIndex])
                return true
            }
        }
        return false
    }

    @discardableResult
    private func mutateWorkout(
        id: UUID,
        mutation: (inout ProgramWorkout) -> Void
    ) -> Bool {
        for programIndex in mutablePrograms.indices {
            for weekIndex in mutablePrograms[programIndex].weeks.indices {
                if let workoutIndex = mutablePrograms[programIndex]
                    .weeks[weekIndex].workouts.firstIndex(
                        where: { $0.id == id }
                    ) {
                    mutation(
                        &mutablePrograms[programIndex].weeks[weekIndex]
                            .workouts[workoutIndex]
                    )
                    return true
                }
            }
        }
        return false
    }

    private func mutateExercise(
        id: UUID,
        mutation: (inout ProgramExercise) -> Void
    ) {
        for programIndex in mutablePrograms.indices {
            for weekIndex in mutablePrograms[programIndex].weeks.indices {
                for workoutIndex in mutablePrograms[programIndex]
                    .weeks[weekIndex].workouts.indices {
                    if let exerciseIndex = mutablePrograms[programIndex]
                        .weeks[weekIndex].workouts[workoutIndex].exercises
                        .firstIndex(where: { $0.id == id }) {
                        mutation(
                            &mutablePrograms[programIndex].weeks[weekIndex]
                                .workouts[workoutIndex]
                                .exercises[exerciseIndex]
                        )
                        return
                    }
                }
            }
        }
    }

    private func replaceContext(
        teams: [OrganizationTeam]? = nil,
        seasons: [OrganizationSeason]? = nil
    ) {
        context = OrganizationContext(
            organizations: context.organizations,
            memberships: members,
            teams: teams ?? context.teams,
            seasons: seasons ?? context.seasons
        )
    }

    private static func makeAthlete(
        id: UUID,
        userID: UUID,
        firstName: String,
        lastName: String,
        position: AthletePosition,
        team: String,
        graduationYear: Int
    ) -> Athlete {
        Athlete(
            id: id,
            userID: userID,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: Calendar.current.date(
                byAdding: .year,
                value: -17,
                to: Date()
            ) ?? Date(),
            heightInches: 72,
            weightPounds: 184,
            position: position,
            team: team,
            graduationYear: graduationYear,
            shoots: .left,
            trainingGoals: "Improve speed, power, and durability."
        )
    }

    private static func makeExercise(
        id: UUID,
        name: String,
        category: ExerciseCategory,
        hockeyCategory: HockeyExerciseCategory,
        muscles: [MuscleGroup],
        equipment: [Equipment]
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            category: category,
            hockeyCategory: hockeyCategory,
            primaryMuscles: muscles,
            secondaryMuscles: [.core],
            equipment: equipment,
            difficulty: .intermediate,
            videoURL: nil,
            instructions: [
                "Set a stable starting position.",
                "Move with control and intent.",
                "Finish each repetition in balance."
            ],
            commonMistakes: ["Losing trunk position"],
            coachTips: ["Own every repetition."],
            substitutions: ["Use the closest pain-free variation."]
        )
    }

    private static func prescription(
        _ exercise: Exercise,
        sets: Int,
        reps: String,
        order: Int
    ) -> WorkoutExercise {
        WorkoutExercise(
            id: UUID(),
            name: exercise.name,
            sets: sets,
            reps: reps,
            restSeconds: 90,
            coachNotes: "Move with intent.",
            exerciseID: exercise.id,
            category: exercise.category.rawValue,
            difficulty: exercise.difficulty.rawValue
        )
    }

    private static func testingResult(
        sessionID: UUID,
        athleteID: UUID,
        metric: TestingMetric,
        value: Double,
        notes: String = "",
        source: TestingResultSource = .coach
    ) -> TestingResult {
        TestingResult(
            id: UUID(),
            sessionID: sessionID,
            metricID: metric.id,
            athleteID: athleteID,
            metricName: metric.name,
            unit: metric.unit,
            direction: metric.direction,
            value: value,
            notes: notes,
            source: source,
            recordedAt: Date()
        )
    }
}

struct DeveloperModeView: View {
    @ObservedObject var store: DeveloperModeStore

    var body: some View {
        Group {
            if let session = store.selectedSession {
                DeveloperRoleContainer(session: session, store: store)
            } else {
                sessionPicker
            }
        }
    }

    private var sessionPicker: some View {
        NavigationStack {
            List {
                Section {
                    Label(
                        "Local, in-memory data. Supabase is not initialized.",
                        systemImage: "hammer.fill"
                    )
                    .foregroundStyle(AppColors.warning)
                } header: {
                    Text("Debug Only")
                }

                Section("Choose a Session") {
                    ForEach(store.sessions) { session in
                        Button {
                            store.selectedSession = session
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: session.role.symbol)
                                    .frame(width: AppSpacing.xl)
                                VStack(alignment: .leading) {
                                    Text(session.role.title)
                                        .font(AppTypography.headline)
                                    Text(session.displayName)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            .frame(
                                minHeight: AppSpacing.minimumTouchTarget
                            )
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityLabel(
                            "Open \(session.role.title) developer session"
                        )
                    }
                }
            }
            .navigationTitle("Developer Mode")
        }
    }
}

private struct DeveloperRoleContainer: View {
    let session: DeveloperSession
    @ObservedObject var store: DeveloperModeStore

    private var athleteService: AthleteService {
        AthleteService(developerStore: store)
    }

    private var trainingRepository: TrainingRepository {
        TrainingRepository(developerStore: store)
    }

    private var programRepository: ProgramRepository {
        ProgramRepository(developerStore: store)
    }

    private var exerciseService: ExerciseService {
        ExerciseService(developerStore: store)
    }

    private var testingRepository: TestingRepository {
        TestingRepository(developerStore: store)
    }

    private var organizationRepository: OrganizationRepository {
        OrganizationRepository(developerStore: store)
    }

    var body: some View {
        VStack(spacing: 0) {
            developerBar
            roleContent
        }
    }

    private var developerBar: some View {
        HStack {
            Button {
                store.resetSession()
            } label: {
                Label("Sessions", systemImage: "chevron.backward")
            }
            Spacer()
            StatusBadge(
                title: "\(session.role.title) • In Memory",
                tone: .warning,
                systemImage: "hammer.fill"
            )
        }
        .font(AppTypography.caption.weight(.semibold))
        .padding(.horizontal, AppSpacing.md)
        .frame(minHeight: AppSpacing.minimumTouchTarget)
        .background(AppColors.elevatedSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private var roleContent: some View {
        switch session.role {
        case .athlete:
            AthleteHomeView(
                athleteService: athleteService,
                trainingRepository: trainingRepository,
                exerciseService: exerciseService,
                testingRepository: testingRepository,
                organizationRepository: organizationRepository,
                showsDeveloperSettings: true
            )
        case .coach:
            CoachHomeView(
                athleteService: athleteService,
                programRepository: programRepository,
                testingRepository: testingRepository,
                organizationRepository: organizationRepository
            )
        case .parent:
            ParentHomeView(
                organizationRepository: organizationRepository,
                testingRepository: testingRepository,
                athleteService: athleteService
            )
        case .forgeAdmin:
            ContentUnavailableView(
                "Admin Console begins in Phase 10",
                systemImage: "wrench.and.screwdriver",
                description: Text(
                    "No production Forge Admin screen exists yet."
                )
            )
        }
    }
}

struct DeveloperSettingsView: View {
    @State private var analyticsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    Toggle("Share Product Analytics", isOn: $analyticsEnabled)
                    Text(
                        "Analytics are privacy-safe and contain no credentials or training details."
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }
                Section("Developer Environment") {
                    LabeledContent("Environment", value: "Debug")
                    LabeledContent("Data", value: "In Memory")
                    LabeledContent("Backend", value: "Disconnected")
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            analyticsEnabled = await AnalyticsService.shared.isEnabled
        }
        .onChange(of: analyticsEnabled) { _, value in
            Task {
                await AnalyticsService.shared.setEnabled(value)
            }
        }
    }
}

private struct DeveloperIDs {
    let organization = Self.id(1)
    let owner = Self.id(2)
    let athleteUser = Self.id(3)
    let athlete = Self.id(4)
    let team = Self.id(5)
    let squat = Self.id(6)
    let bounds = Self.id(7)
    let workout = Self.id(8)
    let assignment = Self.id(9)
    let coach = Self.id(10)
    let parent = Self.id(11)
    let admin = Self.id(12)
    let deadlift = Self.id(13)
    let upcomingWorkout = Self.id(14)
    let completedWorkout = Self.id(15)
    let secondAthlete = Self.id(16)
    let secondAthleteUser = Self.id(17)
    let thirdAthlete = Self.id(18)
    let thirdAthleteUser = Self.id(19)
    let program = Self.id(20)
    let programWeek = Self.id(21)
    let programWorkout = Self.id(22)
    let protocolID = Self.id(23)
    let verticalJump = Self.id(24)
    let sprint = Self.id(25)
    let upcomingTest = Self.id(26)
    let completedTest = Self.id(27)
    let ownerMembership = Self.id(28)
    let athleteMembership = Self.id(29)
    let parentMembership = Self.id(30)
    let teamMembership = Self.id(31)
    let season = Self.id(32)

    private static func id(_ value: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "10000000-0000-0000-0000-%012d",
                value
            )
        )!
    }
}
#endif
