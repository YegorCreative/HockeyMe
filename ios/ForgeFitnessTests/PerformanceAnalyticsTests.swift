import Foundation
import XCTest
@testable import Forge_Fitness

final class PerformanceAnalyticsTests: XCTestCase {
    func testHigherIsBetterImprovement() throws {
        XCTAssertEqual(
            try XCTUnwrap(
                PerformanceAnalytics.improvementPercent(
                    previous: 20,
                    current: 22,
                    direction: .higher
                )
            ),
            10,
            accuracy: 0.001
        )
    }

    func testLowerIsBetterImprovement() throws {
        XCTAssertEqual(
            try XCTUnwrap(
                PerformanceAnalytics.improvementPercent(
                    previous: 5,
                    current: 4.5,
                    direction: .lower
                )
            ),
            10,
            accuracy: 0.001
        )
    }

    func testSeasonAndCareerBestRespectDirection() {
        XCTAssertEqual(
            PerformanceAnalytics.best([5.0, 4.8, 5.1], direction: .lower),
            4.8
        )
        XCTAssertEqual(
            PerformanceAnalytics.best([25, 28, 27], direction: .higher),
            28
        )
    }

    func testPercentileRankingRespectsDirection() {
        XCTAssertEqual(
            PerformanceAnalytics.percentile(
                value: 4.5,
                population: [4.2, 4.5, 4.8, 5.0],
                direction: .lower
            ),
            75
        )
    }

    func testAnalyticsBuildsOrderedHistory() throws {
        let metric = TestingMetric(
            key: "vertical_jump",
            name: "Vertical Jump",
            category: .lowerBody,
            unit: "in"
        )
        let athleteID = UUID()
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        let results = [
            result(metric: metric, athleteID: athleteID, value: 26, date: later),
            result(metric: metric, athleteID: athleteID, value: 24, date: earlier)
        ]

        let analytics = try XCTUnwrap(
            PerformanceAnalytics.analytics(
                metric: metric,
                results: results,
                seasonStart: .distantPast,
                teamValues: [20, 24, 28],
                positionValues: [23, 25]
            )
        )

        XCTAssertEqual(analytics.latest, 26)
        XCTAssertEqual(analytics.careerBest, 26)
        XCTAssertEqual(analytics.history.map(\.date), [earlier, later])
    }

    func testAllRequiredMetricFamiliesAreSupported() {
        let names = Set(StandardTestingMetrics.all.map(\.name))
        let required = [
            "Vertical Jump", "Broad Jump", "10 m Sprint", "20 m Sprint",
            "40 yd Dash", "Pro Agility (5-10-5)", "T-Test",
            "Bench Press", "Trap Bar Deadlift", "Pull-Ups", "Wingate",
            "Medicine Ball Throw", "Yo-Yo Intermittent Recovery Test",
            "Sit and Reach", "Grip Strength", "Height", "Weight",
            "Body Fat %"
        ]
        XCTAssertTrue(Set(required).isSubset(of: names))
    }

    private func result(
        metric: TestingMetric,
        athleteID: UUID,
        value: Double,
        date: Date
    ) -> TestingResult {
        TestingResult(
            id: UUID(),
            sessionID: UUID(),
            metricID: metric.id,
            athleteID: athleteID,
            metricName: metric.name,
            unit: metric.unit,
            direction: metric.direction,
            value: value,
            notes: "",
            source: .coach,
            recordedAt: date
        )
    }
}
