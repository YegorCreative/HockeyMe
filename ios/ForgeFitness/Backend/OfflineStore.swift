import Foundation

actor OfflineStore {
    static let shared = OfflineStore()

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        self.directory = base.appendingPathComponent(
            "ForgeFitnessCache",
            isDirectory: true
        )
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func saveAthlete(_ athlete: Athlete, userID: UUID) throws {
        try save(athlete, as: filename("athlete", userID: userID))
    }

    func athlete(userID: UUID) -> Athlete? {
        load(Athlete.self, from: filename("athlete", userID: userID))
    }

    func saveTrainingPlan(_ plan: TrainingPlan, userID: UUID) throws {
        try save(plan, as: filename("training-plan", userID: userID))
    }

    func trainingPlan(userID: UUID) -> TrainingPlan? {
        load(
            TrainingPlan.self,
            from: filename("training-plan", userID: userID)
        )
    }

    func saveExercises(_ exercises: [Exercise]) throws {
        try save(exercises, as: "exercises.json")
    }

    func exercises() -> [Exercise]? {
        load([Exercise].self, from: "exercises.json")
    }

    func saveTestingSessions(
        _ sessions: [TestingSession],
        userID: UUID
    ) throws {
        try save(sessions, as: filename("testing-sessions", userID: userID))
    }

    func testingSessions(userID: UUID) -> [TestingSession]? {
        load(
            [TestingSession].self,
            from: filename("testing-sessions", userID: userID)
        )
    }

    func saveOrganizationContext(
        _ context: OrganizationContext,
        userID: UUID
    ) throws {
        try save(
            context,
            as: filename("organization-context", userID: userID)
        )
    }

    func organizationContext(userID: UUID) -> OrganizationContext? {
        load(
            OrganizationContext.self,
            from: filename("organization-context", userID: userID)
        )
    }

    func enqueueTestingResult(
        _ result: PendingTestingResult,
        userID: UUID
    ) throws {
        var queue = pendingTestingResults(userID: userID)
        queue.removeAll {
            $0.result.sessionID == result.result.sessionID
                && $0.result.metricID == result.result.metricID
        }
        queue.append(result)
        try save(
            queue,
            as: filename("pending-testing-results", userID: userID)
        )
    }

    func pendingTestingResults(userID: UUID) -> [PendingTestingResult] {
        load(
            [PendingTestingResult].self,
            from: filename("pending-testing-results", userID: userID)
        ) ?? []
    }

    func replacePendingTestingResults(
        _ results: [PendingTestingResult],
        userID: UUID
    ) throws {
        try save(
            results,
            as: filename("pending-testing-results", userID: userID)
        )
    }

    func enqueueSet(_ set: PendingWorkoutSet, userID: UUID) throws {
        var queue = pendingSets(userID: userID)
        if !queue.contains(where: { $0.log.id == set.log.id }) {
            queue.append(set)
            try save(queue, as: filename("pending-sets", userID: userID))
        }
    }

    func pendingSets(userID: UUID) -> [PendingWorkoutSet] {
        load(
            [PendingWorkoutSet].self,
            from: filename("pending-sets", userID: userID)
        ) ?? []
    }

    func replacePendingSets(
        _ sets: [PendingWorkoutSet],
        userID: UUID
    ) throws {
        try save(sets, as: filename("pending-sets", userID: userID))
    }

    func enqueueFinish(_ finish: PendingWorkoutFinish, userID: UUID) throws {
        var queue = pendingFinishes(userID: userID)
        queue.removeAll { $0.sessionID == finish.sessionID }
        queue.append(finish)
        try save(queue, as: filename("pending-finishes", userID: userID))
    }

    func pendingFinishes(userID: UUID) -> [PendingWorkoutFinish] {
        load(
            [PendingWorkoutFinish].self,
            from: filename("pending-finishes", userID: userID)
        ) ?? []
    }

    func replacePendingFinishes(
        _ finishes: [PendingWorkoutFinish],
        userID: UUID
    ) throws {
        try save(finishes, as: filename("pending-finishes", userID: userID))
    }

    private func save<Value: Encodable>(
        _ value: Value,
        as filename: String
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(value)
        try data.write(
            to: directory.appendingPathComponent(filename),
            options: [.atomic, .completeFileProtection]
        )
    }

    private func load<Value: Decodable>(
        _ type: Value.Type,
        from filename: String
    ) -> Value? {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func filename(_ category: String, userID: UUID) -> String {
        "\(category)-\(userID.uuidString.lowercased()).json"
    }
}

struct PendingWorkoutSet: Codable {
    let sessionID: UUID
    let prescriptionID: UUID
    let log: WorkoutSetLog
}

struct PendingWorkoutFinish: Codable {
    let sessionID: UUID
    let startedAt: Date
    let sets: [WorkoutSetLog]
}

struct PendingTestingResult: Codable {
    let result: TestingResult
}
