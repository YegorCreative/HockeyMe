import Foundation
import SwiftUI

enum CoachSection: String, CaseIterable, Identifiable {
    case dashboard, athletes, teams, programming, testing, analytics, organization, settings

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .dashboard: "rectangle.3.group"
        case .athletes: "person.2"
        case .teams: "person.3"
        case .programming: "calendar.badge.clock"
        case .testing: "gauge.with.dots.needle.67percent"
        case .analytics: "chart.xyaxis.line"
        case .organization: "building.2"
        case .settings: "gearshape"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .dashboard: "1"
        case .athletes: "2"
        case .teams: "3"
        case .programming: "4"
        case .testing: "5"
        case .analytics: "6"
        case .organization: "7"
        case .settings: "8"
        }
    }
}

enum CoachBootstrapState: Equatable {
    case developer
    case configured
    case unavailable(String)
}

struct CoachDashboardSnapshot {
    let organizationName: String
    let activeTeams: Int
    let athleteCount: Int
    let currentPrograms: Int
    let upcomingWorkouts: Int
    let recentTests: Int
    let assignedAthletes: Int
}

struct CoachAthleteRecord: Identifiable, Hashable {
    let id: UUID
    var firstName: String
    var lastName: String
    var team: String
    var position: String
    var graduationYear: Int
    var programName: String?
    var trainingStatus: String
    var testingSummary: String
    var season: String

    var name: String { "\(firstName) \(lastName)" }
}

@MainActor
final class CoachAppStore: ObservableObject {
    @Published var selection: CoachSection = .dashboard
    @Published var searchText = ""
    @Published var selectedAthleteIDs: Set<UUID> = []
    @Published var selectedProgramID: UUID?
    @Published var selectedWeekID: UUID?
    @Published var selectedWorkoutID: UUID?
    @Published var bootstrapState: CoachBootstrapState
    @Published var athletes: [CoachAthleteRecord]
    @Published var programs: [TrainingProgram]
    @Published var protocols: [TestingProtocol]
    @Published var testingSessions: [TestingSession]
    @Published var organizations: [Organization]
    @Published var teams: [OrganizationTeam]
    @Published var seasons: [OrganizationSeason]
    @Published var members: [OrganizationMembership]
    @Published var invitations: [OrganizationInvitation]
    @Published var searchFocusRequest = UUID()
    @Published var saveRequest = UUID()

    let isCoachSession: Bool
    let isInMemory: Bool

    init(
        bootstrapState: CoachBootstrapState,
        isCoachSession: Bool,
        isInMemory: Bool,
        athletes: [CoachAthleteRecord] = [],
        programs: [TrainingProgram] = [],
        protocols: [TestingProtocol] = [],
        testingSessions: [TestingSession] = [],
        organizations: [Organization] = [],
        teams: [OrganizationTeam] = [],
        seasons: [OrganizationSeason] = [],
        members: [OrganizationMembership] = [],
        invitations: [OrganizationInvitation] = []
    ) {
        self.bootstrapState = bootstrapState
        self.isCoachSession = isCoachSession
        self.isInMemory = isInMemory
        self.athletes = athletes
        self.programs = programs
        self.protocols = protocols
        self.testingSessions = testingSessions
        self.organizations = organizations
        self.teams = teams
        self.seasons = seasons
        self.members = members
        self.invitations = invitations
        self.selectedProgramID = programs.first?.id
    }

    var dashboard: CoachDashboardSnapshot {
        CoachDashboardSnapshot(
            organizationName: organizations.first?.name ?? "No Organization",
            activeTeams: teams.filter { !$0.isArchived }.count,
            athleteCount: athletes.count,
            currentPrograms: programs.filter { $0.status == .published }.count,
            upcomingWorkouts: programs.flatMap(\.weeks).flatMap(\.workouts).count,
            recentTests: testingSessions.filter { $0.status == .completed }.count,
            assignedAthletes: athletes.filter { $0.programName != nil }.count
        )
    }

    var selectedProgram: TrainingProgram? {
        programs.first { $0.id == selectedProgramID }
    }

    func navigate(to section: CoachSection) {
        selection = section
        searchText = ""
    }

    func focusSearch() {
        searchFocusRequest = UUID()
    }

    func createPrimaryObject() {
        guard isCoachSession else { return }
        switch selection {
        case .programming:
            let program = TrainingProgram(
                id: UUID(),
                name: "Untitled Program",
                description: "",
                status: .draft,
                durationWeeks: 0,
                weeks: []
            )
            programs.insert(program, at: 0)
            selectedProgramID = program.id
        case .testing:
            let protocolValue = TestingProtocol(
                coachUserID: UUID(),
                name: "Untitled Protocol"
            )
            protocols.insert(protocolValue, at: 0)
        case .teams:
            guard let organizationID = organizations.first?.id else { return }
            teams.append(
                OrganizationTeam(
                    id: UUID(),
                    organizationID: organizationID,
                    name: "Untitled Team",
                    ageGroup: "",
                    isArchived: false
                )
            )
        default:
            break
        }
    }

    func duplicateSelectedProgram() {
        guard let program = selectedProgram else { return }
        let copy = TrainingProgram(
            id: UUID(),
            name: "\(program.name) Copy",
            description: program.description,
            status: .draft,
            durationWeeks: program.durationWeeks,
            weeks: program.weeks.map { week in
                TrainingProgramWeek(
                    id: UUID(),
                    weekNumber: week.weekNumber,
                    name: week.name,
                    focus: week.focus,
                    workouts: week.workouts.map { workout in
                        ProgramWorkout(
                            id: UUID(),
                            name: workout.name,
                            description: workout.description,
                            dayNumber: workout.dayNumber,
                            estimatedDurationMinutes: workout.estimatedDurationMinutes,
                            sortOrder: workout.sortOrder,
                            exercises: workout.exercises.map { exercise in
                                ProgramExercise(
                                    id: UUID(),
                                    exerciseID: exercise.exerciseID,
                                    name: exercise.name,
                                    sets: exercise.sets,
                                    repsMin: exercise.repsMin,
                                    repsMax: exercise.repsMax,
                                    restSeconds: exercise.restSeconds,
                                    tempo: exercise.tempo,
                                    notes: exercise.notes,
                                    coachCues: exercise.coachCues,
                                    sortOrder: exercise.sortOrder
                                )
                            }
                        )
                    }
                )
            }
        )
        programs.insert(copy, at: 0)
        selectedProgramID = copy.id
    }

    func addWeek() {
        guard let index = programs.firstIndex(where: { $0.id == selectedProgramID }) else { return }
        let number = programs[index].weeks.count + 1
        programs[index].weeks.append(
            TrainingProgramWeek(
                id: UUID(),
                weekNumber: number,
                name: "Week \(number)",
                focus: "",
                workouts: []
            )
        )
        programs[index].durationWeeks = programs[index].weeks.count
        selectedWeekID = programs[index].weeks.last?.id
    }

    func addWorkout(to weekID: UUID) {
        guard let programIndex = programs.firstIndex(where: { $0.id == selectedProgramID }),
              let weekIndex = programs[programIndex].weeks.firstIndex(where: { $0.id == weekID }) else {
            return
        }
        let count = programs[programIndex].weeks[weekIndex].workouts.count
        let workout = ProgramWorkout(
            id: UUID(),
            name: "Untitled Workout",
            description: "",
            dayNumber: count + 1,
            estimatedDurationMinutes: 45,
            sortOrder: count,
            exercises: []
        )
        programs[programIndex].weeks[weekIndex].workouts.append(workout)
        selectedWorkoutID = workout.id
    }

    func togglePublish() {
        guard let index = programs.firstIndex(where: { $0.id == selectedProgramID }) else { return }
        let canPublish = programs[index].weeks.contains { !$0.workouts.isEmpty }
        guard programs[index].status == .published || canPublish else { return }
        programs[index].status = programs[index].status == .published ? .draft : .published
    }

    func archiveSelectedProgram() {
        guard let index = programs.firstIndex(where: { $0.id == selectedProgramID }) else { return }
        programs[index].status = .archived
    }

    func addExercise(to workoutID: UUID, exercise: ProgramExerciseChoice) {
        guard let programIndex = programs.firstIndex(where: { $0.id == selectedProgramID }) else { return }
        for weekIndex in programs[programIndex].weeks.indices {
            guard let workoutIndex = programs[programIndex].weeks[weekIndex].workouts
                .firstIndex(where: { $0.id == workoutID }) else { continue }
            let order = programs[programIndex].weeks[weekIndex].workouts[workoutIndex].exercises.count
            programs[programIndex].weeks[weekIndex].workouts[workoutIndex].exercises.append(
                ProgramExercise(
                    id: UUID(),
                    exerciseID: exercise.id,
                    name: exercise.name,
                    sets: 3,
                    repsMin: 5,
                    repsMax: 5,
                    restSeconds: 120,
                    tempo: "",
                    notes: "",
                    coachCues: "",
                    sortOrder: order
                )
            )
            return
        }
    }

    func assignSelectedProgram(to athleteID: UUID) {
        guard let index = athletes.firstIndex(where: { $0.id == athleteID }),
              let program = selectedProgram else { return }
        athletes[index].programName = program.name
    }

    func save() {
        saveRequest = UUID()
    }
}

enum CoachAppBootstrap {
    @MainActor
    static func makeStore(bundle: Bundle = .main) -> CoachAppStore {
#if DEBUG
        if MacSupabaseConfiguration.load(bundle: bundle, environment: .debug) == nil {
            return DeveloperCoachData.store()
        }
#endif
        let environment = MacBuildEnvironment.current
        guard let configuration = MacSupabaseConfiguration.load(
            bundle: bundle,
            environment: environment
        ) else {
            return CoachAppStore(
                bootstrapState: .unavailable(
                    "Forge Coach is not configured for \(environment.title)."
                ),
                isCoachSession: false,
                isInMemory: false
            )
        }
        guard configuration.isAllowed(for: environment) else {
            return CoachAppStore(
                bootstrapState: .unavailable("Environment safety validation failed."),
                isCoachSession: false,
                isInMemory: false
            )
        }
        return CoachAppStore(
            bootstrapState: .configured,
            isCoachSession: false,
            isInMemory: false
        )
    }
}
