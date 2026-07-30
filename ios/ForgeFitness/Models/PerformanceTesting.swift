import Foundation

enum TestingProtocolStatus: String, Codable, CaseIterable {
    case draft
    case active
    case inactive
    case archived
}

enum TestingMetricCategory: String, Codable, CaseIterable, Identifiable {
    case lowerBody = "lower_body"
    case speed
    case agility
    case strength
    case power
    case endurance
    case mobility
    case grip
    case bodyComposition = "body_composition"
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .lowerBody: "Lower Body"
        case .bodyComposition: "Body Composition"
        default: rawValue.capitalized
        }
    }
}

enum TestingValueDirection: String, Codable {
    case higher
    case lower
}

struct TestingMetric: Identifiable, Codable, Hashable {
    let id: UUID
    var key: String
    var name: String
    var category: TestingMetricCategory
    var unit: String
    var direction: TestingValueDirection
    var isRequired: Bool
    var sortOrder: Int
    var instructions: String

    init(
        id: UUID = UUID(),
        key: String,
        name: String,
        category: TestingMetricCategory,
        unit: String,
        direction: TestingValueDirection = .higher,
        isRequired: Bool = true,
        sortOrder: Int = 0,
        instructions: String = ""
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.category = category
        self.unit = unit
        self.direction = direction
        self.isRequired = isRequired
        self.sortOrder = sortOrder
        self.instructions = instructions
    }
}

struct TestingProtocol: Identifiable, Codable, Hashable {
    let id: UUID
    var coachUserID: UUID
    var parentProtocolID: UUID?
    var name: String
    var description: String
    var version: Int
    var status: TestingProtocolStatus
    var allowsAthleteEntry: Bool
    var metrics: [TestingMetric]

    init(
        id: UUID = UUID(),
        coachUserID: UUID,
        parentProtocolID: UUID? = nil,
        name: String,
        description: String = "",
        version: Int = 1,
        status: TestingProtocolStatus = .draft,
        allowsAthleteEntry: Bool = false,
        metrics: [TestingMetric] = []
    ) {
        self.id = id
        self.coachUserID = coachUserID
        self.parentProtocolID = parentProtocolID
        self.name = name
        self.description = description
        self.version = version
        self.status = status
        self.allowsAthleteEntry = allowsAthleteEntry
        self.metrics = metrics
    }
}

enum TestingSessionStatus: String, Codable {
    case scheduled
    case inProgress = "in_progress"
    case completed
    case cancelled
}

struct TestingSession: Identifiable, Codable, Hashable {
    let id: UUID
    let protocolID: UUID
    let athleteID: UUID
    var protocolName: String
    var athleteName: String
    var athletePosition: String
    var scheduledAt: Date
    var completedAt: Date?
    var seasonLabel: String
    var location: String
    var status: TestingSessionStatus
    var allowsAthleteEntry: Bool
    var metrics: [TestingMetric]
    var results: [TestingResult]
}

enum TestingResultSource: String, Codable {
    case coach
    case athlete
    case importSource = "import"
}

struct TestingResult: Identifiable, Codable, Hashable {
    let id: UUID
    let sessionID: UUID
    let metricID: UUID
    let athleteID: UUID
    let metricName: String
    let unit: String
    let direction: TestingValueDirection
    var value: Double
    var notes: String
    let source: TestingResultSource
    let recordedAt: Date
}

struct TestingMetricAnalytics: Identifiable, Equatable {
    let metricID: UUID
    let metricName: String
    let unit: String
    let latest: Double
    let previous: Double?
    let improvementPercent: Double?
    let seasonBest: Double
    let careerBest: Double
    let teamAverage: Double?
    let positionAverage: Double?
    let percentile: Double?
    let history: [TestingTrendPoint]

    var id: UUID { metricID }
}

struct TestingTrendPoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct TestingDashboardSummary: Equatable {
    let strongestAthletes: [String]
    let mostImprovedAthletes: [String]
    let completionPercent: Double
    let missingTestCount: Int
    let teamAverages: [String: Double]
}

enum StandardTestingMetrics {
    static let all: [TestingMetric] = [
        metric("vertical_jump", "Vertical Jump", .lowerBody, "in"),
        metric("broad_jump", "Broad Jump", .lowerBody, "in"),
        metric("sprint_10m", "10 m Sprint", .speed, "s", .lower),
        metric("sprint_20m", "20 m Sprint", .speed, "s", .lower),
        metric("dash_40yd", "40 yd Dash", .speed, "s", .lower),
        metric("pro_agility", "Pro Agility (5-10-5)", .agility, "s", .lower),
        metric("t_test", "T-Test", .agility, "s", .lower),
        metric("bench_press", "Bench Press", .strength, "lb"),
        metric("trap_bar_deadlift", "Trap Bar Deadlift", .strength, "lb"),
        metric("pull_ups", "Pull-Ups", .strength, "reps"),
        metric("wingate", "Wingate", .power, "W"),
        metric("medicine_ball_throw", "Medicine Ball Throw", .power, "ft"),
        metric("yoyo_ir", "Yo-Yo Intermittent Recovery Test", .endurance, "m"),
        metric("sit_and_reach", "Sit and Reach", .mobility, "in"),
        metric("grip_strength", "Grip Strength", .grip, "lb"),
        metric("height", "Height", .bodyComposition, "in"),
        metric("weight", "Weight", .bodyComposition, "lb"),
        metric("body_fat_percent", "Body Fat %", .bodyComposition, "%", .lower)
    ].enumerated().map { index, metric in
        var metric = metric
        metric.sortOrder = index
        return metric
    }

    private static func metric(
        _ key: String,
        _ name: String,
        _ category: TestingMetricCategory,
        _ unit: String,
        _ direction: TestingValueDirection = .higher
    ) -> TestingMetric {
        TestingMetric(
            key: key,
            name: name,
            category: category,
            unit: unit,
            direction: direction
        )
    }
}

enum PerformanceAnalytics {
    static func analytics(
        metric: TestingMetric,
        results: [TestingResult],
        seasonStart: Date,
        teamValues: [Double] = [],
        positionValues: [Double] = []
    ) -> TestingMetricAnalytics? {
        let matching = results
            .filter { $0.metricID == metric.id }
            .sorted { $0.recordedAt < $1.recordedAt }
        guard let latest = matching.last else { return nil }
        let previous = matching.dropLast().last
        let improvement = previous.flatMap {
            improvementPercent(
                previous: $0.value,
                current: latest.value,
                direction: metric.direction
            )
        }
        let seasonValues = matching
            .filter { $0.recordedAt >= seasonStart }
            .map(\.value)
        let allValues = matching.map(\.value)
        let comparison = teamValues.sorted()

        return TestingMetricAnalytics(
            metricID: metric.id,
            metricName: metric.name,
            unit: metric.unit,
            latest: latest.value,
            previous: previous?.value,
            improvementPercent: improvement,
            seasonBest: best(seasonValues, direction: metric.direction)
                ?? latest.value,
            careerBest: best(allValues, direction: metric.direction)
                ?? latest.value,
            teamAverage: average(teamValues),
            positionAverage: average(positionValues),
            percentile: percentile(
                value: latest.value,
                population: comparison,
                direction: metric.direction
            ),
            history: matching.map {
                TestingTrendPoint(date: $0.recordedAt, value: $0.value)
            }
        )
    }

    static func improvementPercent(
        previous: Double,
        current: Double,
        direction: TestingValueDirection
    ) -> Double? {
        guard previous != 0 else { return nil }
        let change = direction == .higher
            ? current - previous
            : previous - current
        return (change / abs(previous)) * 100
    }

    static func best(
        _ values: [Double],
        direction: TestingValueDirection
    ) -> Double? {
        direction == .higher ? values.max() : values.min()
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func percentile(
        value: Double,
        population: [Double],
        direction: TestingValueDirection
    ) -> Double? {
        guard !population.isEmpty else { return nil }
        let favorable = population.filter {
            direction == .higher ? $0 <= value : $0 >= value
        }.count
        return Double(favorable) / Double(population.count) * 100
    }
}
