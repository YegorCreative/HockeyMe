#if DEBUG
import Foundation

enum DeveloperCoachData {
    @MainActor
    static func store() -> CoachAppStore {
        let organizationID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let ownerID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let teamID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let programID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let exerciseID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let metric = TestingMetric(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            key: "vertical_jump",
            name: "Vertical Jump",
            category: .lowerBody,
            unit: "in"
        )
        let athleteID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
        let sessionID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
        let protocolID = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!

        let athletes = [
            CoachAthleteRecord(
                id: athleteID,
                firstName: "Yegor",
                lastName: "Hambaryan",
                team: "U18 Forge",
                position: "Center",
                graduationYear: 2027,
                programName: "Off-Season Strength",
                trainingStatus: "Completed today",
                testingSummary: "Vertical Jump 25.4 in",
                season: "2026–27"
            ),
            CoachAthleteRecord(
                id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
                firstName: "Maya",
                lastName: "Chen",
                team: "U18 Forge",
                position: "Defense",
                graduationYear: 2027,
                programName: "Off-Season Strength",
                trainingStatus: "Workout due",
                testingSummary: "10 m Sprint 1.81 s",
                season: "2026–27"
            ),
            CoachAthleteRecord(
                id: UUID(uuidString: "50000000-0000-0000-0000-000000000003")!,
                firstName: "Liam",
                lastName: "O'Connor",
                team: "U16 Forge",
                position: "Goalie",
                graduationYear: 2029,
                programName: nil,
                trainingStatus: "Unassigned",
                testingSummary: "Testing scheduled",
                season: "2026–27"
            )
        ]

        let exercise = ProgramExercise(
            id: UUID(),
            exerciseID: exerciseID,
            name: "Trap Bar Deadlift",
            sets: 4,
            repsMin: 4,
            repsMax: 4,
            restSeconds: 150,
            tempo: "2-0-X",
            notes: "Build clean speed from the floor.",
            coachCues: "Brace, push the ice away.",
            sortOrder: 0
        )
        let workout = ProgramWorkout(
            id: UUID(),
            name: "Lower Strength A",
            description: "Primary lower-body strength session.",
            dayNumber: 1,
            estimatedDurationMinutes: 60,
            sortOrder: 0,
            exercises: [exercise]
        )
        let week = TrainingProgramWeek(
            id: UUID(),
            weekNumber: 1,
            name: "Foundation",
            focus: "Movement quality and force production",
            workouts: [workout]
        )
        let program = TrainingProgram(
            id: programID,
            name: "Off-Season Strength",
            description: "Four-week strength foundation.",
            status: .published,
            durationWeeks: 1,
            weeks: [week]
        )

        let protocolValue = TestingProtocol(
            id: protocolID,
            coachUserID: ownerID,
            name: "Preseason Combine",
            description: "Baseline hockey performance testing.",
            version: 1,
            status: .active,
            metrics: [metric]
        )
        let result = TestingResult(
            id: UUID(),
            sessionID: sessionID,
            metricID: metric.id,
            athleteID: athleteID,
            metricName: metric.name,
            unit: metric.unit,
            direction: metric.direction,
            value: 25.4,
            notes: "",
            source: .coach,
            recordedAt: Date().addingTimeInterval(-86_400)
        )
        let testSession = TestingSession(
            id: sessionID,
            protocolID: protocolID,
            athleteID: athleteID,
            protocolName: protocolValue.name,
            athleteName: athletes[0].name,
            athletePosition: athletes[0].position,
            scheduledAt: Date().addingTimeInterval(-86_400),
            completedAt: Date().addingTimeInterval(-86_000),
            seasonLabel: "2026–27",
            location: "Forge Performance Lab",
            status: .completed,
            allowsAthleteEntry: false,
            metrics: [metric],
            results: [result]
        )

        return CoachAppStore(
            bootstrapState: .developer,
            isCoachSession: true,
            isInMemory: true,
            athletes: athletes,
            programs: [program],
            protocols: [protocolValue],
            testingSessions: [testSession],
            organizations: [
                Organization(
                    id: organizationID,
                    name: "Forge Hockey Academy",
                    slug: "forge-hockey-academy",
                    ownerUserID: ownerID
                )
            ],
            teams: [
                OrganizationTeam(
                    id: teamID,
                    organizationID: organizationID,
                    name: "U18 Forge",
                    ageGroup: "U18",
                    isArchived: false
                ),
                OrganizationTeam(
                    id: UUID(),
                    organizationID: organizationID,
                    name: "U16 Forge",
                    ageGroup: "U16",
                    isArchived: false
                )
            ],
            seasons: [
                OrganizationSeason(
                    id: UUID(),
                    organizationID: organizationID,
                    name: "2026–27",
                    startsOn: Date(),
                    endsOn: Date().addingTimeInterval(31_536_000),
                    isArchived: false
                )
            ],
            members: [
                OrganizationMembership(
                    id: UUID(),
                    organizationID: organizationID,
                    userID: ownerID,
                    displayName: "Alex Morgan",
                    email: "coach@example.invalid",
                    roles: [.organizationOwner, .headCoach],
                    status: "active"
                )
            ],
            invitations: [
                OrganizationInvitation(
                    id: UUID(),
                    organizationID: organizationID,
                    email: "assistant@example.invalid",
                    roles: [.assistantCoach],
                    status: "pending",
                    expiresAt: Date().addingTimeInterval(604_800)
                )
            ]
        )
    }
}
#endif
