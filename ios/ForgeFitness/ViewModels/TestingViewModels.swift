import Combine
import Foundation
import SwiftUI

enum TestingViewerRole {
    case coach
    case athlete
    case parent
}

@MainActor
final class TestingDashboardViewModel: ObservableObject {
    @Published private(set) var protocols: [TestingProtocol] = []
    @Published private(set) var sessions: [TestingSession] = []
    @Published private(set) var athletes: [Athlete] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var syncMessage: String?

    let role: TestingViewerRole
    let repository: TestingRepository
    private let athleteService: AthleteService
    private var hasLoaded = false

    init(
        role: TestingViewerRole,
        repository: TestingRepository,
        athleteService: AthleteService
    ) {
        self.role = role
        self.repository = repository
        self.athleteService = athleteService
    }

    var upcomingSessions: [TestingSession] {
        sessions.filter {
            $0.status == .scheduled && $0.scheduledAt >= Date()
        }.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var completedSessions: [TestingSession] {
        sessions.filter { $0.status == .completed }
    }

    var personalRecords: [TestingMetricAnalytics] {
        analytics.compactMap { item in
            guard item.latest == item.careerBest else { return nil }
            return item
        }
    }

    var analytics: [TestingMetricAnalytics] {
        let metrics = Dictionary(
            uniqueKeysWithValues: sessions
                .flatMap(\.metrics)
                .map { ($0.id, $0) }
        )
        let results = sessions.flatMap(\.results)
        let seasonStart = Calendar.current.date(
            byAdding: .year,
            value: -1,
            to: Date()
        ) ?? .distantPast
        return metrics.values.compactMap { metric in
            let metricResults = results.filter { $0.metricID == metric.id }
            let latestAthleteID = metricResults.max {
                $0.recordedAt < $1.recordedAt
            }?.athleteID
            let latestPosition = sessions.first {
                $0.athleteID == latestAthleteID
            }?.athletePosition
            let positionAthleteIDs = Set(sessions.filter {
                $0.athletePosition == latestPosition
            }.map(\.athleteID))
            return PerformanceAnalytics.analytics(
                metric: metric,
                results: results,
                seasonStart: seasonStart,
                teamValues: role == .coach
                    ? metricResults.map(\.value)
                    : [],
                positionValues: role == .coach
                    ? metricResults.filter {
                        positionAthleteIDs.contains($0.athleteID)
                    }.map(\.value)
                    : []
            )
        }.sorted { $0.metricName < $1.metricName }
    }

    var coachSummary: TestingDashboardSummary {
        let completed = Double(completedSessions.count)
        let total = Double(sessions.count)
        let grouped = Dictionary(grouping: sessions.flatMap(\.results)) {
            $0.metricName
        }
        return TestingDashboardSummary(
            strongestAthletes: strongestAthletes,
            mostImprovedAthletes: mostImprovedAthletes,
            completionPercent: total == 0 ? 0 : completed / total * 100,
            missingTestCount: sessions.filter {
                $0.status == .scheduled && $0.scheduledAt < Date()
            }.count,
            teamAverages: grouped.compactMapValues {
                PerformanceAnalytics.average($0.map(\.value))
            }
        )
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func refresh() async {
        await load()
    }

    func retry() async {
        await load()
    }

    func duplicate(_ value: TestingProtocol) async {
        await perform {
            _ = try await repository.duplicateProtocol(value)
            await load()
        }
    }

    func schedule(
        protocolValue: TestingProtocol,
        athleteIDs: [UUID],
        date: Date,
        season: String,
        location: String
    ) async {
        await perform {
            try await repository.schedule(
                protocolID: protocolValue.id,
                athleteIDs: athleteIDs,
                date: date,
                season: season,
                location: location
            )
            await load()
        }
    }

    func record(
        session: TestingSession,
        metric: TestingMetric,
        value: Double,
        notes: String
    ) async {
        await perform {
            _ = try await repository.record(
                session: session,
                metric: metric,
                value: value,
                notes: notes,
                source: role == .coach ? .coach : .athlete
            )
            await AnalyticsService.shared.track(.testingResultRecorded)
            syncMessage = await repository.hasPendingResults()
                ? "Saved offline — sync pending"
                : "Synced"
            await load()
        }
    }

    func complete(_ session: TestingSession) async {
        await perform {
            try await repository.complete(sessionID: session.id)
            await load()
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let loadedSessions = repository.loadSessions()
            if role == .coach {
                async let loadedProtocols = repository.loadProtocols()
                async let loadedAthletes = athleteService.loadCoachAthletes()
                protocols = try await loadedProtocols
                athletes = try await loadedAthletes
            }
            sessions = try await loadedSessions
            syncMessage = await repository.hasPendingResults()
                ? "Offline changes pending"
                : nil
            hasLoaded = true
        } catch {
            errorMessage = Self.message(error)
        }
        isLoading = false
    }

    private func perform(
        _ operation: () async throws -> Void
    ) async {
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = Self.message(error)
        }
    }

    private var strongestAthletes: [String] {
        let grouped = Dictionary(grouping: sessions.flatMap(\.results)) {
            $0.athleteID
        }
        return grouped.sorted {
            ($0.value.map(\.value).reduce(0, +) / Double($0.value.count))
                > ($1.value.map(\.value).reduce(0, +) / Double($1.value.count))
        }.prefix(3).compactMap { entry in
            sessions.first { $0.athleteID == entry.key }?.athleteName
        }
    }

    private var mostImprovedAthletes: [String] {
        let grouped = Dictionary(grouping: sessions) { $0.athleteID }
        return grouped.compactMap { athleteID, sessions -> (String, Double)? in
            let results = sessions.flatMap(\.results)
            guard results.count > 1 else { return nil }
            let ordered = results.sorted { $0.recordedAt < $1.recordedAt }
            guard let first = ordered.first, let last = ordered.last,
                  let value = PerformanceAnalytics.improvementPercent(
                    previous: first.value,
                    current: last.value,
                    direction: last.direction
                  ) else { return nil }
            return (sessions.first?.athleteName ?? athleteID.uuidString, value)
        }.sorted { $0.1 > $1.1 }.prefix(3).map(\.0)
    }

    private static func message(_ error: Error) -> String {
        (error as NSError).domain == NSURLErrorDomain
            ? "You're offline. Cached testing data is shown when available."
            : error.localizedDescription
    }
}

@MainActor
final class TestingProtocolEditorViewModel: ObservableObject {
    @Published var name: String
    @Published var description: String
    @Published var allowsAthleteEntry: Bool
    @Published var status: TestingProtocolStatus
    @Published var metrics: [TestingMetric]
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    private let repository: TestingRepository
    private let original: TestingProtocol?

    init(
        protocolValue: TestingProtocol? = nil,
        repository: TestingRepository
    ) {
        original = protocolValue
        self.repository = repository
        name = protocolValue?.name ?? ""
        description = protocolValue?.description ?? ""
        allowsAthleteEntry = protocolValue?.allowsAthleteEntry ?? false
        status = protocolValue?.status ?? .draft
        metrics = protocolValue?.metrics ?? []
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !metrics.isEmpty
    }

    func addStandardMetric(_ metric: TestingMetric) {
        guard !metrics.contains(where: { $0.key == metric.key }) else {
            return
        }
        var metric = metric
        metric.sortOrder = metrics.count
        metrics.append(metric)
    }

    func addCustomMetric(
        name: String,
        unit: String,
        category: TestingMetricCategory
    ) {
        let key = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        guard !key.isEmpty, !unit.isEmpty else { return }
        metrics.append(
            TestingMetric(
                key: key,
                name: name,
                category: category,
                unit: unit,
                sortOrder: metrics.count
            )
        )
    }

    func removeMetrics(at offsets: IndexSet) {
        metrics.remove(atOffsets: offsets)
    }

    func save() async -> Bool {
        guard canSave else {
            errorMessage = TestingRepositoryError.invalidProtocol
                .localizedDescription
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            if var original {
                original.name = name
                original.description = description
                original.allowsAthleteEntry = allowsAthleteEntry
                original.status = status
                original.metrics = metrics
                try await repository.updateProtocol(original)
            } else {
                _ = try await repository.createProtocol(
                    name: name,
                    description: description,
                    allowsAthleteEntry: allowsAthleteEntry,
                    metrics: metrics
                )
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
