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

@MainActor
final class DeveloperModeStore: ObservableObject {
    @Published var selectedSession: DeveloperSession?
    @Published var athlete: Athlete

    let sessions: [DeveloperSession]
    let organization: Organization
    let team: OrganizationTeam
    let workout: Workout
    let exercises: [Exercise]

    init() {
        let organizationID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let ownerID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let athleteUserID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let athleteID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!

        organization = Organization(
            id: organizationID,
            name: "Forge Hockey Academy",
            slug: "forge-hockey-academy",
            ownerUserID: ownerID
        )
        team = OrganizationTeam(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
            organizationID: organizationID,
            name: "U18 Forge",
            ageGroup: "U18",
            isArchived: false
        )
        athlete = Athlete(
            id: athleteID,
            userID: athleteUserID,
            firstName: "Yegor",
            lastName: "Hambaryan",
            dateOfBirth: Calendar.current.date(
                byAdding: .year,
                value: -17,
                to: Date()
            ) ?? Date(),
            heightInches: 72,
            weightPounds: 184,
            position: .center,
            team: "U18 Forge",
            graduationYear: 2027,
            shoots: .left,
            trainingGoals: "Improve first-step speed and lower-body power."
        )

        let squat = Exercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
            name: "Back Squat",
            category: .strength,
            hockeyCategory: .skatingStrength,
            primaryMuscles: [.quadriceps, .glutes],
            secondaryMuscles: [.hamstrings, .core],
            equipment: [.barbell],
            difficulty: .intermediate,
            videoURL: nil,
            instructions: ["Brace the trunk.", "Descend with control.", "Drive through the floor."],
            commonMistakes: ["Losing trunk position"],
            coachTips: ["Keep pressure through the full foot."],
            substitutions: ["Front Squat", "Trap Bar Deadlift"]
        )
        let bounds = Exercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
            name: "Lateral Bounds",
            category: .plyometrics,
            hockeyCategory: .lateralPower,
            primaryMuscles: [.glutes, .adductors],
            secondaryMuscles: [.quadriceps, .core],
            equipment: [.bodyweight],
            difficulty: .intermediate,
            videoURL: nil,
            instructions: ["Load the outside hip.", "Bound laterally.", "Stick the landing."],
            commonMistakes: ["Collapsing at the knee"],
            coachTips: ["Own each landing before the next rep."],
            substitutions: ["Skater Hops"]
        )
        exercises = [squat, bounds]
        workout = Workout(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
            title: "Lower Body Power",
            description: "Skating-strength and lateral-power development.",
            estimatedDurationMinutes: 55,
            scheduledDate: Date(),
            status: .scheduled,
            exercises: [
                WorkoutExercise(
                    name: squat.name,
                    sets: 4,
                    reps: "5",
                    restSeconds: 120,
                    coachNotes: "Move with intent. Tempo: 3-1-X-1.",
                    exerciseID: squat.id,
                    category: squat.category.rawValue,
                    difficulty: squat.difficulty.rawValue
                ),
                WorkoutExercise(
                    name: bounds.name,
                    sets: 3,
                    reps: "6 each side",
                    restSeconds: 75,
                    coachNotes: "Stick every landing.",
                    exerciseID: bounds.id,
                    category: bounds.category.rawValue,
                    difficulty: bounds.difficulty.rawValue
                )
            ],
            assignmentID: UUID(uuidString: "10000000-0000-0000-0000-000000000009")
        )
        sessions = [
            DeveloperSession(
                id: athleteUserID,
                role: .athlete,
                displayName: "Yegor Hambaryan",
                email: "athlete@developer.invalid",
                organizationRoles: [.athlete]
            ),
            DeveloperSession(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000010")!,
                role: .coach,
                displayName: "Alex Morgan",
                email: "coach@developer.invalid",
                organizationRoles: [.headCoach, .strengthCoach]
            ),
            DeveloperSession(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!,
                role: .parent,
                displayName: "Jordan Hambaryan",
                email: "parent@developer.invalid",
                organizationRoles: [.parent]
            ),
            DeveloperSession(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!,
                role: .forgeAdmin,
                displayName: "Forge Platform Admin",
                email: "admin@developer.invalid",
                organizationRoles: [.organizationOwner, .administrator]
            )
        ]
    }
}

struct DeveloperModeView: View {
    @ObservedObject var store: DeveloperModeStore

    var body: some View {
        Group {
            if let session = store.selectedSession {
                DeveloperSessionView(session: session, store: store)
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
                        "No Supabase Debug configuration was found. All data in this mode stays in memory.",
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
                                    .frame(width: 32)
                                VStack(alignment: .leading) {
                                    Text(session.role.title)
                                        .font(AppTypography.headline)
                                    Text(session.displayName)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityLabel("Open \(session.role.title) developer session")
                    }
                }
            }
            .navigationTitle("Developer Mode")
        }
    }
}

private struct DeveloperSessionView: View {
    let session: DeveloperSession
    @ObservedObject var store: DeveloperModeStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DeveloperSummaryCard(session: session, store: store)
                }

                Section("Screens") {
                    ForEach(destinations, id: \.title) { destination in
                        NavigationLink {
                            DeveloperFeatureView(
                                title: destination.title,
                                symbol: destination.symbol,
                                session: session,
                                store: store
                            )
                        } label: {
                            Label(destination.title, systemImage: destination.symbol)
                        }
                    }
                }
            }
            .navigationTitle(session.role.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sessions") {
                        store.selectedSession = nil
                    }
                }
            }
        }
    }

    private var destinations: [(title: String, symbol: String)] {
        switch session.role {
        case .athlete:
            [
                ("Home", "house.fill"),
                ("Workouts", "dumbbell.fill"),
                ("Workout Session", "figure.strengthtraining.traditional"),
                ("Workout Summary", "checkmark.circle.fill"),
                ("Exercise Library", "books.vertical.fill"),
                ("Testing", "stopwatch.fill"),
                ("Teams & Seasons", "person.3.fill"),
                ("Profile", "person.crop.circle.fill")
            ]
        case .coach:
            [
                ("Coach Dashboard", "rectangle.grid.2x2.fill"),
                ("Athletes", "person.3.fill"),
                ("Athlete Detail", "person.text.rectangle"),
                ("Programs", "list.clipboard.fill"),
                ("Program Editor", "square.and.pencil"),
                ("Exercise Library", "books.vertical.fill"),
                ("Testing", "stopwatch.fill"),
                ("Organization", "building.2.fill"),
                ("Invitations", "envelope.badge")
            ]
        case .parent:
            [
                ("Parent Dashboard", "house.fill"),
                ("Linked Athlete", "person.crop.circle"),
                ("Workouts", "dumbbell.fill"),
                ("Testing History", "chart.line.uptrend.xyaxis"),
                ("Attendance", "calendar.badge.checkmark"),
                ("Progress", "chart.bar.fill")
            ]
        case .forgeAdmin:
            [
                ("Platform Overview", "gauge.with.dots.needle.67percent"),
                ("Organizations", "building.2.fill"),
                ("Members & Roles", "person.badge.key.fill"),
                ("Feature Flags", "flag.2.crossed.fill"),
                ("Environment Health", "waveform.path.ecg"),
                ("Sync Operations", "arrow.triangle.2.circlepath")
            ]
        }
    }
}

private struct DeveloperSummaryCard: View {
    let session: DeveloperSession
    let store: DeveloperModeStore

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(session.displayName)
                .font(AppTypography.title)
            Text(session.email)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            Label(store.organization.name, systemImage: "building.2")
            Text(session.organizationRoles.map(\.title).joined(separator: " • "))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct DeveloperFeatureView: View {
    let title: String
    let symbol: String
    let session: DeveloperSession
    let store: DeveloperModeStore

    var body: some View {
        List {
            Section {
                Label(title, systemImage: symbol)
                    .font(AppTypography.title)
            }
            Section("Live In-Memory Context") {
                LabeledContent("Session", value: session.role.title)
                LabeledContent("Organization", value: store.organization.name)
                LabeledContent("Team", value: store.team.name)
                LabeledContent(
                    "Athlete",
                    value: "\(store.athlete.firstName) \(store.athlete.lastName)"
                )
                LabeledContent("Workout", value: store.workout.title)
                LabeledContent("Exercises", value: "\(store.exercises.count)")
            }
            Section("Sample Data") {
                ForEach(store.exercises) { exercise in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(exercise.name)
                            .font(AppTypography.headline)
                        Text("\(exercise.hockeyCategory.rawValue) • \(exercise.difficulty.rawValue)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
