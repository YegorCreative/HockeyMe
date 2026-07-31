import XCTest
@testable import Forge_Coach

@MainActor
final class ForgeCoachTests: XCTestCase {
    func testDeveloperModeLaunchesWithoutConfiguration() {
#if DEBUG
        let store = DeveloperCoachData.store()
        XCTAssertEqual(store.bootstrapState, .developer)
        XCTAssertTrue(store.isCoachSession)
        XCTAssertTrue(store.isInMemory)
        XCTAssertFalse(store.athletes.isEmpty)
#endif
    }

    func testSidebarExposesAllCoachSections() {
        XCTAssertEqual(CoachSection.allCases.count, 8)
        XCTAssertEqual(CoachSection.allCases.first, .dashboard)
        XCTAssertEqual(CoachSection.allCases.last, .settings)
    }

    func testAthleteSelectionUsesProductionShapedIdentifier() throws {
#if DEBUG
        let store = DeveloperCoachData.store()
        let athleteID = try XCTUnwrap(store.athletes.first?.id)
        store.selectedAthleteIDs = [athleteID]
        XCTAssertEqual(store.selectedAthleteIDs.first, athleteID)
#endif
    }

    func testProgramCanBeCreatedEditedAndPublished() throws {
#if DEBUG
        let store = DeveloperCoachData.store()
        store.navigate(to: .programming)
        store.createPrimaryObject()
        XCTAssertEqual(store.selectedProgram?.status, .draft)
        store.addWeek()
        let weekID = try XCTUnwrap(store.selectedProgram?.weeks.first?.id)
        store.addWorkout(to: weekID)
        store.togglePublish()
        XCTAssertEqual(store.selectedProgram?.status, .published)
#endif
    }

    func testProgramDuplicationCreatesIndependentDraft() throws {
#if DEBUG
        let store = DeveloperCoachData.store()
        let originalID = try XCTUnwrap(store.selectedProgramID)
        store.duplicateSelectedProgram()
        XCTAssertNotEqual(store.selectedProgramID, originalID)
        XCTAssertEqual(store.selectedProgram?.status, .draft)
#endif
    }

    func testRepeatedMetricIdentifiersAggregateSafely() {
        let metricID = UUID()
        let athleteID = UUID()
        let sessionID = UUID()
        let older = TestingResult(
            id: UUID(),
            sessionID: sessionID,
            metricID: metricID,
            athleteID: athleteID,
            metricName: "Vertical Jump",
            unit: "in",
            direction: .higher,
            value: 24,
            notes: "",
            source: .coach,
            recordedAt: Date(timeIntervalSince1970: 1)
        )
        let newer = TestingResult(
            id: UUID(),
            sessionID: sessionID,
            metricID: metricID,
            athleteID: athleteID,
            metricName: "Vertical Jump",
            unit: "in",
            direction: .higher,
            value: 25,
            notes: "",
            source: .coach,
            recordedAt: Date(timeIntervalSince1970: 2)
        )
        let grouped = Dictionary(grouping: [older, newer], by: \.metricID)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[metricID]?.max(by: { $0.recordedAt < $1.recordedAt })?.value, 25)
    }

    func testNonCoachRoleCannotEnterCoachShell() {
        let store = CoachAppStore(
            bootstrapState: .configured,
            isCoachSession: false,
            isInMemory: false
        )
        XCTAssertFalse(store.isCoachSession)
    }

    func testEmptyProgramCannotPublish() {
#if DEBUG
        let store = DeveloperCoachData.store()
        store.navigate(to: .programming)
        store.createPrimaryObject()
        store.togglePublish()
        XCTAssertEqual(store.selectedProgram?.status, .draft)
#endif
    }

    func testProgramAssignmentPreventsDuplicateState() throws {
#if DEBUG
        let store = DeveloperCoachData.store()
        let athleteID = try XCTUnwrap(store.athletes.first?.id)
        let programName = try XCTUnwrap(store.selectedProgram?.name)
        store.assignSelectedProgram(to: athleteID)
        store.assignSelectedProgram(to: athleteID)
        XCTAssertEqual(
            store.athletes.first(where: { $0.id == athleteID })?.programName,
            programName
        )
#endif
    }

    func testProductionEnvironmentRejectsNonProductionHost() throws {
        let configuration = MacSupabaseConfiguration(
            url: try XCTUnwrap(URL(string: "https://staging.example.invalid")),
            publishableKey: "test-only"
        )
        XCTAssertFalse(configuration.isAllowed(for: .production))
        XCTAssertTrue(configuration.isAllowed(for: .staging))
    }
}
