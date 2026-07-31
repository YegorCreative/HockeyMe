import Foundation
import Supabase

enum TestingRepositoryError: LocalizedError {
    case invalidProtocol
    case profileMissing
    case selfEntryNotAllowed
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .invalidProtocol:
            "Add a protocol name and at least one metric."
        case .profileMissing:
            "The athlete profile could not be found."
        case .selfEntryNotAllowed:
            "This test must be recorded by your coach."
        case .invalidResult:
            "Enter a valid testing result."
        }
    }
}

final class TestingRepository: @unchecked Sendable {
    private let client: SupabaseClient!
    private let offlineStore: OfflineStore
    private let connectivityMonitor: ConnectivityMonitor
    private let synchronizationGate = SynchronizationGate()
#if DEBUG
    private let developerStore: DeveloperModeStore?
#endif

    init(
        client: SupabaseClient,
        offlineStore: OfflineStore = .shared,
        connectivityMonitor: ConnectivityMonitor = ConnectivityMonitor()
    ) {
        self.client = client
        self.offlineStore = offlineStore
        self.connectivityMonitor = connectivityMonitor
#if DEBUG
        developerStore = nil
#endif
        connectivityMonitor.start { [weak self] in
            Task { try? await self?.synchronizePendingResults() }
        }
    }

#if DEBUG
    init(developerStore: DeveloperModeStore) {
        client = nil
        offlineStore = .shared
        connectivityMonitor = ConnectivityMonitor()
        self.developerStore = developerStore
    }
#endif

    func loadProtocols() async throws -> [TestingProtocol] {
#if DEBUG
        if let developerStore {
            return await developerStore.testingProtocols()
        }
#endif
        let rows: [ProtocolRecord] = try await client
            .from("testing_protocols")
            .select(
                "id,coach_user_id,parent_protocol_id,name,description,version,status,allows_athlete_entry,testing_metrics(id,metric_key,name,category,unit,value_direction,is_required,sort_order,instructions)"
            )
            .order("updated_at", ascending: false)
            .execute()
            .value
        return rows.compactMap(\.protocolValue)
    }

    func createProtocol(
        name: String,
        description: String,
        allowsAthleteEntry: Bool,
        metrics: [TestingMetric]
    ) async throws -> TestingProtocol {
#if DEBUG
        if let developerStore {
            return try await developerStore.createTestingProtocol(
                name: name,
                description: description,
                allowsAthleteEntry: allowsAthleteEntry,
                metrics: metrics
            )
        }
#endif
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !metrics.isEmpty else {
            throw TestingRepositoryError.invalidProtocol
        }
        let userID = try await client.auth.session.user.id
        let protocolID = UUID()
        let payload = ProtocolPayload(
            id: protocolID,
            coachUserID: userID,
            parentProtocolID: nil,
            name: trimmed,
            description: description,
            version: 1,
            status: .draft,
            allowsAthleteEntry: allowsAthleteEntry
        )
        try await client.from("testing_protocols").insert(payload).execute()
        try await replaceMetrics(metrics, protocolID: protocolID)
        return TestingProtocol(
            id: protocolID,
            coachUserID: userID,
            name: trimmed,
            description: description,
            allowsAthleteEntry: allowsAthleteEntry,
            metrics: metrics
        )
    }

    func updateProtocol(_ value: TestingProtocol) async throws {
#if DEBUG
        if let developerStore {
            try await developerStore.updateTestingProtocol(value)
            return
        }
#endif
        guard !value.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty, !value.metrics.isEmpty else {
            throw TestingRepositoryError.invalidProtocol
        }
        try await client.from("testing_protocols")
            .update(
                ProtocolUpdate(
                    name: value.name,
                    description: value.description,
                    status: value.status,
                    allowsAthleteEntry: value.allowsAthleteEntry
                )
            )
            .eq("id", value: value.id)
            .execute()
        try await replaceMetrics(value.metrics, protocolID: value.id)
    }

    func duplicateProtocol(
        _ source: TestingProtocol
    ) async throws -> TestingProtocol {
#if DEBUG
        if let developerStore {
            return await developerStore.duplicateTestingProtocol(source)
        }
#endif
        let userID = try await client.auth.session.user.id
        let id = UUID()
        let copy = TestingProtocol(
            id: id,
            coachUserID: userID,
            parentProtocolID: source.id,
            name: "\(source.name) Copy",
            description: source.description,
            version: source.version + 1,
            status: .draft,
            allowsAthleteEntry: source.allowsAthleteEntry,
            metrics: source.metrics.map {
                TestingMetric(
                    key: $0.key,
                    name: $0.name,
                    category: $0.category,
                    unit: $0.unit,
                    direction: $0.direction,
                    isRequired: $0.isRequired,
                    sortOrder: $0.sortOrder,
                    instructions: $0.instructions
                )
            }
        )
        try await client.from("testing_protocols")
            .insert(
                ProtocolPayload(
                    id: copy.id,
                    coachUserID: copy.coachUserID,
                    parentProtocolID: copy.parentProtocolID,
                    name: copy.name,
                    description: copy.description,
                    version: copy.version,
                    status: copy.status,
                    allowsAthleteEntry: copy.allowsAthleteEntry
                )
            )
            .execute()
        try await replaceMetrics(copy.metrics, protocolID: copy.id)
        return copy
    }

    func schedule(
        protocolID: UUID,
        athleteIDs: [UUID],
        date: Date,
        season: String,
        location: String
    ) async throws {
#if DEBUG
        if let developerStore {
            await developerStore.scheduleTesting(
                protocolID: protocolID,
                athleteIDs: athleteIDs,
                date: date,
                season: season,
                location: location
            )
            return
        }
#endif
        let userID = try await client.auth.session.user.id
        let payloads = athleteIDs.map {
            SessionPayload(
                id: UUID(),
                protocolID: protocolID,
                athleteID: $0,
                scheduledAt: Self.timestamp(date),
                seasonLabel: season,
                location: location,
                createdBy: userID
            )
        }
        guard !payloads.isEmpty else { return }
        try await client.from("testing_sessions")
            .upsert(
                payloads,
                onConflict: "protocol_id,athlete_id,scheduled_at"
            )
            .execute()
    }

    func loadSessions() async throws -> [TestingSession] {
#if DEBUG
        if let developerStore {
            return await developerStore.testingSessions()
        }
#endif
        let userID = try await client.auth.session.user.id
        do {
            try await synchronizePendingResults()
            let rows: [SessionRecord] = try await client
                .from("testing_sessions")
                .select(
                    "id,protocol_id,athlete_id,scheduled_at,completed_at,season_label,location,status,testing_protocols(name,allows_athlete_entry,testing_metrics(id,metric_key,name,category,unit,value_direction,is_required,sort_order,instructions)),athletes(first_name,last_name,position),testing_results(id,session_id,metric_id,athlete_id,numeric_value,notes,source,recorded_at,testing_metrics(name,unit,value_direction))"
                )
                .order("scheduled_at", ascending: false)
                .execute()
                .value
            let sessions = rows.compactMap(\.session)
            try? await offlineStore.saveTestingSessions(
                sessions,
                userID: userID
            )
            return sessions
        } catch {
            if let cached = await offlineStore.testingSessions(
                userID: userID
            ) {
                return cached
            }
            throw error
        }
    }

    func record(
        session: TestingSession,
        metric: TestingMetric,
        value: Double,
        notes: String,
        source: TestingResultSource
    ) async throws -> TestingResult {
#if DEBUG
        if let developerStore {
            return try await developerStore.recordTestingResult(
                session: session,
                metric: metric,
                value: value,
                notes: notes,
                source: source
            )
        }
#endif
        guard value.isFinite else {
            throw TestingRepositoryError.invalidResult
        }
        if source == .athlete, !session.allowsAthleteEntry {
            throw TestingRepositoryError.selfEntryNotAllowed
        }
        let userID = try await client.auth.session.user.id
        let result = TestingResult(
            id: UUID(),
            sessionID: session.id,
            metricID: metric.id,
            athleteID: session.athleteID,
            metricName: metric.name,
            unit: metric.unit,
            direction: metric.direction,
            value: value,
            notes: notes,
            source: source,
            recordedAt: Date()
        )
        do {
            try await upsert(result, recordedBy: userID)
            return result
        } catch where Self.isNetworkError(error) {
            try await offlineStore.enqueueTestingResult(
                PendingTestingResult(result: result),
                userID: userID
            )
            return result
        }
    }

    func complete(sessionID: UUID) async throws {
#if DEBUG
        if let developerStore {
            await developerStore.completeTestingSession(id: sessionID)
            return
        }
#endif
        try await client.from("testing_sessions")
            .update(
                SessionCompletion(
                    status: .completed,
                    completedAt: Self.timestamp(Date())
                )
            )
            .eq("id", value: sessionID)
            .execute()
    }

    func synchronizePendingResults() async throws {
        try await synchronizationGate.run { [self] in
            try await performPendingResultSynchronization()
        }
    }

    private func performPendingResultSynchronization() async throws {
#if DEBUG
        if developerStore != nil {
            return
        }
#endif
        let userID = try await client.auth.session.user.id
        var remaining: [PendingTestingResult] = []
        for pending in await offlineStore.pendingTestingResults(
            userID: userID
        ) {
            do {
                try await upsert(pending.result, recordedBy: userID)
            } catch {
                remaining.append(pending)
                if !Self.isNetworkError(error) { throw error }
            }
        }
        try await offlineStore.replacePendingTestingResults(
            remaining,
            userID: userID
        )
    }

    func hasPendingResults() async -> Bool {
#if DEBUG
        if developerStore != nil {
            return false
        }
#endif
        guard let userID = try? await client.auth.session.user.id else {
            return false
        }
        return !(await offlineStore.pendingTestingResults(
            userID: userID
        )).isEmpty
    }

    private func replaceMetrics(
        _ metrics: [TestingMetric],
        protocolID: UUID
    ) async throws {
        let payloads = metrics.enumerated().map { index, metric in
            MetricPayload(
                id: metric.id,
                protocolID: protocolID,
                key: metric.key,
                name: metric.name,
                category: metric.category,
                unit: metric.unit,
                direction: metric.direction,
                isRequired: metric.isRequired,
                sortOrder: index,
                instructions: metric.instructions
            )
        }
        try await client.from("testing_metrics")
            .upsert(payloads, onConflict: "id")
            .execute()
    }

    private func upsert(
        _ result: TestingResult,
        recordedBy: UUID
    ) async throws {
        try await client.from("testing_results")
            .upsert(
                ResultPayload(
                    id: result.id,
                    sessionID: result.sessionID,
                    metricID: result.metricID,
                    athleteID: result.athleteID,
                    value: result.value,
                    notes: result.notes,
                    source: result.source,
                    recordedBy: recordedBy,
                    recordedAt: Self.timestamp(result.recordedAt)
                ),
                onConflict: "session_id,metric_id"
            )
            .execute()
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    fileprivate static func date(_ string: String?) -> Date? {
        string.flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        (error as NSError).domain == NSURLErrorDomain
    }
}

private struct ProtocolRecord: Decodable {
    let id: UUID
    let coachUserID: UUID
    let parentProtocolID: UUID?
    let name: String
    let description: String
    let version: Int
    let status: TestingProtocolStatus
    let allowsAthleteEntry: Bool
    let metrics: [MetricRecord]
    var protocolValue: TestingProtocol? {
        TestingProtocol(
            id: id,
            coachUserID: coachUserID,
            parentProtocolID: parentProtocolID,
            name: name,
            description: description,
            version: version,
            status: status,
            allowsAthleteEntry: allowsAthleteEntry,
            metrics: metrics.map(\.metric).sorted {
                $0.sortOrder < $1.sortOrder
            }
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name, description, version, status
        case coachUserID = "coach_user_id"
        case parentProtocolID = "parent_protocol_id"
        case allowsAthleteEntry = "allows_athlete_entry"
        case metrics = "testing_metrics"
    }
}

private struct MetricRecord: Decodable {
    let id: UUID
    let key: String
    let name: String
    let category: TestingMetricCategory
    let unit: String
    let direction: TestingValueDirection
    let isRequired: Bool
    let sortOrder: Int
    let instructions: String
    var metric: TestingMetric {
        TestingMetric(
            id: id,
            key: key,
            name: name,
            category: category,
            unit: unit,
            direction: direction,
            isRequired: isRequired,
            sortOrder: sortOrder,
            instructions: instructions
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name, category, unit, instructions
        case key = "metric_key"
        case direction = "value_direction"
        case isRequired = "is_required"
        case sortOrder = "sort_order"
    }
}

private struct SessionRecord: Decodable {
    let id: UUID
    let protocolID: UUID
    let athleteID: UUID
    let scheduledAt: String
    let completedAt: String?
    let seasonLabel: String
    let location: String
    let status: TestingSessionStatus
    let protocolValue: SessionProtocolRecord
    let athlete: SessionAthleteRecord
    let results: [ResultRecord]
    var session: TestingSession? {
        guard let scheduled = TestingRepository.date(scheduledAt) else {
            return nil
        }
        return TestingSession(
            id: id,
            protocolID: protocolID,
            athleteID: athleteID,
            protocolName: protocolValue.name,
            athleteName: "\(athlete.firstName) \(athlete.lastName)",
            athletePosition: athlete.position,
            scheduledAt: scheduled,
            completedAt: TestingRepository.date(completedAt),
            seasonLabel: seasonLabel,
            location: location,
            status: status,
            allowsAthleteEntry: protocolValue.allowsAthleteEntry,
            metrics: protocolValue.metrics.map(\.metric),
            results: results.compactMap(\.result)
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, status, location
        case protocolID = "protocol_id"
        case athleteID = "athlete_id"
        case scheduledAt = "scheduled_at"
        case completedAt = "completed_at"
        case seasonLabel = "season_label"
        case protocolValue = "testing_protocols"
        case athlete = "athletes"
        case results = "testing_results"
    }
}

private struct SessionProtocolRecord: Decodable {
    let name: String
    let allowsAthleteEntry: Bool
    let metrics: [MetricRecord]
    enum CodingKeys: String, CodingKey {
        case name
        case allowsAthleteEntry = "allows_athlete_entry"
        case metrics = "testing_metrics"
    }
}

private struct SessionAthleteRecord: Decodable {
    let firstName: String
    let lastName: String
    let position: String
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case position
    }
}

private struct ResultRecord: Decodable {
    let id: UUID
    let sessionID: UUID
    let metricID: UUID
    let athleteID: UUID
    let value: Double
    let notes: String
    let source: TestingResultSource
    let recordedAt: String
    let metric: ResultMetricRecord
    var result: TestingResult? {
        guard let date = TestingRepository.date(recordedAt) else {
            return nil
        }
        return TestingResult(
            id: id,
            sessionID: sessionID,
            metricID: metricID,
            athleteID: athleteID,
            metricName: metric.name,
            unit: metric.unit,
            direction: metric.direction,
            value: value,
            notes: notes,
            source: source,
            recordedAt: date
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, notes, source
        case sessionID = "session_id"
        case metricID = "metric_id"
        case athleteID = "athlete_id"
        case value = "numeric_value"
        case recordedAt = "recorded_at"
        case metric = "testing_metrics"
    }
}

private struct ResultMetricRecord: Decodable {
    let name: String
    let unit: String
    let direction: TestingValueDirection
    enum CodingKeys: String, CodingKey {
        case name, unit
        case direction = "value_direction"
    }
}

private struct ProtocolPayload: Encodable {
    let id: UUID
    let coachUserID: UUID
    let parentProtocolID: UUID?
    let name: String
    let description: String
    let version: Int
    let status: TestingProtocolStatus
    let allowsAthleteEntry: Bool
    enum CodingKeys: String, CodingKey {
        case id, name, description, version, status
        case coachUserID = "coach_user_id"
        case parentProtocolID = "parent_protocol_id"
        case allowsAthleteEntry = "allows_athlete_entry"
    }
}

private struct ProtocolUpdate: Encodable {
    let name: String
    let description: String
    let status: TestingProtocolStatus
    let allowsAthleteEntry: Bool
    enum CodingKeys: String, CodingKey {
        case name, description, status
        case allowsAthleteEntry = "allows_athlete_entry"
    }
}

private struct MetricPayload: Encodable {
    let id: UUID
    let protocolID: UUID
    let key: String
    let name: String
    let category: TestingMetricCategory
    let unit: String
    let direction: TestingValueDirection
    let isRequired: Bool
    let sortOrder: Int
    let instructions: String
    enum CodingKeys: String, CodingKey {
        case id, name, category, unit, instructions
        case protocolID = "protocol_id"
        case key = "metric_key"
        case direction = "value_direction"
        case isRequired = "is_required"
        case sortOrder = "sort_order"
    }
}

private struct SessionPayload: Encodable {
    let id: UUID
    let protocolID: UUID
    let athleteID: UUID
    let scheduledAt: String
    let seasonLabel: String
    let location: String
    let createdBy: UUID
    enum CodingKeys: String, CodingKey {
        case id, location
        case protocolID = "protocol_id"
        case athleteID = "athlete_id"
        case scheduledAt = "scheduled_at"
        case seasonLabel = "season_label"
        case createdBy = "created_by"
    }
}

private struct ResultPayload: Encodable {
    let id: UUID
    let sessionID: UUID
    let metricID: UUID
    let athleteID: UUID
    let value: Double
    let notes: String
    let source: TestingResultSource
    let recordedBy: UUID
    let recordedAt: String
    enum CodingKeys: String, CodingKey {
        case id, notes, source
        case sessionID = "session_id"
        case metricID = "metric_id"
        case athleteID = "athlete_id"
        case value = "numeric_value"
        case recordedBy = "recorded_by"
        case recordedAt = "recorded_at"
    }
}

private struct SessionCompletion: Encodable {
    let status: TestingSessionStatus
    let completedAt: String
    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
    }
}
