import XCTest
@testable import Forge_Fitness

final class BusinessRuleTests: XCTestCase {
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
