import Foundation
import XCTest
@testable import Forge_Fitness

final class OfflineStoreTests: XCTestCase {
    private var directory: URL!
    private var store: OfflineStore!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        store = OfflineStore(directory: directory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testAthleteProfileRoundTrip() async throws {
        let userID = UUID()
        let athlete = Athlete(
            userID: userID,
            firstName: "Alex",
            lastName: "Smith",
            dateOfBirth: Date(timeIntervalSince1970: 1_000),
            heightInches: 72,
            weightPounds: 185,
            position: .center,
            team: "Forge",
            graduationYear: 2027,
            shoots: .left,
            trainingGoals: "Improve first-step speed"
        )

        try await store.saveAthlete(athlete, userID: userID)
        let restored = await store.athlete(userID: userID)

        XCTAssertEqual(restored?.userID, athlete.userID)
        XCTAssertEqual(restored?.trainingGoals, athlete.trainingGoals)
    }

    func testTrainingPlanAndExerciseLibraryRoundTrip() async throws {
        let userID = UUID()
        let exercise = Exercise(
            name: "Lateral Bounds",
            category: .plyometrics,
            hockeyCategory: .lateralPower,
            primaryMuscles: [.glutes],
            secondaryMuscles: [.adductors],
            equipment: [.bodyweight],
            difficulty: .intermediate,
            videoURL: nil,
            instructions: ["Load the outside hip.", "Stick the landing."],
            commonMistakes: ["Losing balance"],
            coachTips: ["Own each landing"],
            substitutions: ["Skater Hops"]
        )
        let workout = Workout(
            title: "Lateral Power",
            description: "Quality movement",
            estimatedDurationMinutes: 35,
            scheduledDate: Date(timeIntervalSince1970: 2_000),
            status: .scheduled,
            exercises: []
        )

        try await store.saveExercises([exercise])
        try await store.saveTrainingPlan(
            TrainingPlan(workouts: [workout]),
            userID: userID
        )

        let restoredExercises = await store.exercises()
        let restoredPlan = await store.trainingPlan(userID: userID)
        XCTAssertEqual(restoredExercises?.first?.name, "Lateral Bounds")
        XCTAssertEqual(
            restoredPlan?.workouts.first?.title,
            "Lateral Power"
        )
    }

    func testPendingSetQueueIsIdempotent() async throws {
        let userID = UUID()
        let log = WorkoutSetLog(
            exerciseID: UUID(),
            exerciseName: "Back Squat",
            setNumber: 1,
            weight: 225,
            reps: 5,
            rpe: 8,
            painLevel: 1,
            notes: ""
        )
        let pending = PendingWorkoutSet(
            sessionID: UUID(),
            prescriptionID: UUID(),
            log: log
        )

        try await store.enqueueSet(pending, userID: userID)
        try await store.enqueueSet(pending, userID: userID)

        let queued = await store.pendingSets(userID: userID)
        XCTAssertEqual(queued.count, 1)
    }

    func testPendingFinishReplacesSameSession() async throws {
        let userID = UUID()
        let sessionID = UUID()
        try await store.enqueueFinish(
            PendingWorkoutFinish(
                sessionID: sessionID,
                startedAt: Date(),
                sets: []
            ),
            userID: userID
        )
        try await store.enqueueFinish(
            PendingWorkoutFinish(
                sessionID: sessionID,
                startedAt: Date(),
                sets: []
            ),
            userID: userID
        )

        let queued = await store.pendingFinishes(userID: userID)
        XCTAssertEqual(queued.count, 1)
    }

    func testUserCachesAreIsolated() async throws {
        let firstUser = UUID()
        let secondUser = UUID()
        let athlete = Athlete(
            userID: firstUser,
            firstName: "First",
            lastName: "Athlete",
            dateOfBirth: Date(),
            heightInches: 70,
            weightPounds: 170,
            position: .center,
            team: "Forge",
            graduationYear: 2027,
            shoots: .right,
            trainingGoals: "Power"
        )

        try await store.saveAthlete(athlete, userID: firstUser)

        let firstCache = await store.athlete(userID: firstUser)
        let secondCache = await store.athlete(userID: secondUser)
        XCTAssertNotNil(firstCache)
        XCTAssertNil(secondCache)
    }

    func testPendingTestingResultReplacesMetricConflict() async throws {
        let userID = UUID()
        let sessionID = UUID()
        let metricID = UUID()
        let athleteID = UUID()
        func pending(value: Double) -> PendingTestingResult {
            PendingTestingResult(
                result: TestingResult(
                    id: UUID(),
                    sessionID: sessionID,
                    metricID: metricID,
                    athleteID: athleteID,
                    metricName: "Vertical Jump",
                    unit: "in",
                    direction: .higher,
                    value: value,
                    notes: "",
                    source: .athlete,
                    recordedAt: Date()
                )
            )
        }

        try await store.enqueueTestingResult(
            pending(value: 24),
            userID: userID
        )
        try await store.enqueueTestingResult(
            pending(value: 25),
            userID: userID
        )

        let queued = await store.pendingTestingResults(userID: userID)
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.result.value, 25)
    }
}
