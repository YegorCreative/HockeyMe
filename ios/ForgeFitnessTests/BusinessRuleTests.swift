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
}
