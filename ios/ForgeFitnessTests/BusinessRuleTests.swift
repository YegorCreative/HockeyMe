import XCTest
@testable import Forge_Fitness

final class BusinessRuleTests: XCTestCase {
    func testDebugBuildCannotPresentAsProduction() {
#if DEBUG
        XCTAssertEqual(AppEnvironment.build, .debug)
        XCTAssertFalse(AppEnvironment.build.isProduction)
        XCTAssertEqual(
            AppEnvironment.build.configurationResource,
            "SupabaseConfig-Debug"
        )
#endif
    }

    func testFeatureFlagKillSwitchAndAudienceRules() {
        let userID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000007"
        )!
        let base = FeatureFlag(
            id: UUID(),
            key: "testing_beta",
            enabled: true,
            environments: [.staging],
            audience: .beta,
            rolloutPercentage: 100,
            minimumVersion: "1.2.0",
            payload: [:]
        )
        let beta = FeatureFlagContext(
            userID: userID,
            isInternalUser: false,
            isBetaUser: true
        )
        XCTAssertTrue(
            FeatureFlagEvaluator.isEnabled(
                base,
                key: base.key,
                environment: .staging,
                context: beta,
                appVersion: "1.2.0"
            )
        )
        XCTAssertFalse(
            FeatureFlagEvaluator.isEnabled(
                base,
                key: base.key,
                environment: .production,
                context: beta,
                appVersion: "1.2.0"
            )
        )

        let disabled = FeatureFlag(
            id: base.id,
            key: base.key,
            enabled: false,
            environments: base.environments,
            audience: base.audience,
            rolloutPercentage: 100,
            minimumVersion: base.minimumVersion,
            payload: [:]
        )
        XCTAssertFalse(
            FeatureFlagEvaluator.isEnabled(
                disabled,
                key: disabled.key,
                environment: .staging,
                context: beta,
                appVersion: "1.2.0"
            )
        )
    }

    func testAnalyticsCanBeDisabled() async {
        let suite = "AnalyticsServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let analytics = AnalyticsService(defaults: defaults)
        await analytics.setEnabled(false)
        let enabled = await analytics.isEnabled
        XCTAssertFalse(enabled)
    }

    func testWorkoutSetIdentitySurvivesEncoding() throws {
        let set = WorkoutSetLog(
            exerciseID: UUID(),
            exerciseName: "Trap Bar Deadlift",
            setNumber: 2,
            weight: 315,
            reps: 4,
            rpe: 8,
            painLevel: 1,
            notes: "Fast bar speed"
        )

        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(
            WorkoutSetLog.self,
            from: data
        )

        XCTAssertEqual(decoded.id, set.id)
        XCTAssertEqual(decoded.weight, 315)
        XCTAssertEqual(decoded.reps, 4)
    }

    func testTrainingRepositoryErrorsAreFriendly() {
        XCTAssertNotNil(
            TrainingRepositoryError.activeAssignmentMissing.errorDescription
        )
        XCTAssertNotNil(
            TrainingRepositoryError.sessionUnavailable.errorDescription
        )
    }

    func testErrorPresentationSeparatesRecoveryCategories() {
        let offline = AppErrorPresentation.make(
            for: URLError(.notConnectedToInternet)
        )
        XCTAssertEqual(offline.kind, .network)
        XCTAssertTrue(offline.canRetry)
        XCTAssertNotNil(offline.recoveryAction)

        let permission = AppErrorPresentation.make(
            for: AthleteServiceError.unauthorized
        )
        XCTAssertEqual(permission.kind, .permission)
        XCTAssertFalse(permission.canRetry)

        let cancellation = AppErrorPresentation.make(
            for: CancellationError()
        )
        XCTAssertEqual(cancellation.kind, .cancellation)
        XCTAssertFalse(cancellation.canRetry)
    }

    func testSynchronizationGateCoalescesConcurrentWork() async throws {
        let gate = SynchronizationGate()
        let counter = Phase10Counter()

        async let first: Void = gate.run {
            await counter.increment()
            try await Task.sleep(for: .milliseconds(40))
        }
        async let second: Void = gate.run {
            await counter.increment()
            try await Task.sleep(for: .milliseconds(40))
        }

        _ = try await (first, second)
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }

#if DEBUG
    @MainActor
    func testDeveloperRepositoriesUseProductionModelsInMemory() async throws {
        let store = DeveloperModeStore()
        let athleteService = AthleteService(developerStore: store)
        let exerciseService = ExerciseService(developerStore: store)
        let trainingRepository = TrainingRepository(developerStore: store)
        let testingRepository = TestingRepository(developerStore: store)
        let programRepository = ProgramRepository(developerStore: store)
        let organizationRepository = OrganizationRepository(
            developerStore: store
        )

        let hasProfile = try await athleteService.hasProfile()
        let exercises = try await exerciseService.fetchExercises()
        let plan = try await trainingRepository.loadActiveTrainingPlan()
        let protocols = try await testingRepository.loadProtocols()
        let programs = try await programRepository.loadPrograms()
        let context = try await organizationRepository.loadContext()

        XCTAssertTrue(hasProfile)
        XCTAssertFalse(exercises.isEmpty)
        XCTAssertFalse(plan.workouts.isEmpty)
        XCTAssertFalse(protocols.isEmpty)
        XCTAssertFalse(programs.isEmpty)
        XCTAssertFalse(context.organizations.isEmpty)
    }

    @MainActor
    func testDeveloperWorkoutSessionIsRestoredWithoutDuplicates() async throws {
        let store = DeveloperModeStore()
        let repository = TrainingRepository(developerStore: store)
        let plan = try await repository.loadActiveTrainingPlan()
        let workout = try XCTUnwrap(plan.workouts.first)

        let first = try await repository.startSession(for: workout)
        let second = try await repository.startSession(for: workout)
        let restored = try await repository.restoreSession(for: workout)
        let hasPendingLogs = await repository.hasPendingLogs()

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(restored?.id, first.id)
        XCTAssertFalse(hasPendingLogs)
    }

    @MainActor
    func testDeveloperTestingHistoryDeduplicatesProtocolMetrics() async {
        let store = DeveloperModeStore()
        let viewModel = TestingDashboardViewModel(
            role: .athlete,
            repository: TestingRepository(developerStore: store),
            athleteService: AthleteService(developerStore: store)
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.sessions.count, 2)
        XCTAssertEqual(Set(viewModel.analytics.map(\.metricID)).count, 2)
    }
#endif
}

private actor Phase10Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
