import Foundation
import Supabase

struct TrainingPlan: Codable {
    let workouts: [Workout]
}

struct RestoredWorkoutSession {
    let id: UUID
    let startedAt: Date
    let sets: [WorkoutSetLog]
}

enum TrainingRepositoryError: LocalizedError {
    case athleteProfileMissing
    case activeAssignmentMissing
    case invalidTrainingData
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .athleteProfileMissing:
            "Your athlete profile could not be found."
        case .activeAssignmentMissing:
            "No active training program is assigned yet."
        case .invalidTrainingData:
            "Some training data could not be loaded."
        case .sessionUnavailable:
            "The workout session could not be opened."
        }
    }
}

final class TrainingRepository: @unchecked Sendable {
    private let client: SupabaseClient
    private let offlineStore: OfflineStore
    private let connectivityMonitor: ConnectivityMonitor

    init(
        client: SupabaseClient,
        offlineStore: OfflineStore = .shared,
        connectivityMonitor: ConnectivityMonitor = ConnectivityMonitor()
    ) {
        self.client = client
        self.offlineStore = offlineStore
        self.connectivityMonitor = connectivityMonitor
        connectivityMonitor.start { [weak self] in
            Task {
                try? await self?.synchronizePendingLogs()
            }
        }
    }

    func loadActiveTrainingPlan() async throws -> TrainingPlan {
        let userID = try await client.auth.session.user.id
        do {
            try await synchronizePendingLogs()
            let response = try await client
                .rpc("get_active_training_plan")
                .execute()
            let payload = try JSONDecoder().decode(
                ActivePlanPayload?.self,
                from: response.data
            )
            guard let payload else {
                throw TrainingRepositoryError.activeAssignmentMissing
            }
            let plan = payload.trainingPlan
            try? await offlineStore.saveTrainingPlan(plan, userID: userID)
            return plan
        } catch {
            if let cached = await offlineStore.trainingPlan(userID: userID) {
                return cached
            }
            throw error
        }
    }

    func restoreSession(
        for workout: Workout
    ) async throws -> RestoredWorkoutSession? {
        let athleteID = try await currentAthleteID()
        let sessions: [SessionRecord] = try await client
            .from("workout_sessions")
            .select()
            .eq("athlete_id", value: athleteID)
            .eq("workout_id", value: workout.id)
            .eq("status", value: "in_progress")
            .limit(1)
            .execute()
            .value

        guard let session = sessions.first else {
            return nil
        }

        return RestoredWorkoutSession(
            id: session.id,
            startedAt: try Self.parseTimestamp(session.startedAt),
            sets: try await loadSets(
                sessionID: session.id,
                workout: workout
            )
        )
    }

    func startSession(for workout: Workout) async throws -> RestoredWorkoutSession {
        if let existing = try await restoreSession(for: workout) {
            return existing
        }

        guard let assignmentID = workout.assignmentID else {
            throw TrainingRepositoryError.sessionUnavailable
        }

        let insert = SessionInsert(
            athleteID: try await currentAthleteID(),
            assignmentID: assignmentID,
            workoutID: workout.id,
            status: "in_progress",
            startedAt: Self.timestamp(Date())
        )

        do {
            let session: SessionRecord = try await client
                .from("workout_sessions")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            return RestoredWorkoutSession(
                id: session.id,
                startedAt: try Self.parseTimestamp(session.startedAt),
                sets: []
            )
        } catch {
            if let restored = try await restoreSession(for: workout) {
                return restored
            }
            throw error
        }
    }

    func saveSet(
        _ set: WorkoutSetLog,
        sessionID: UUID,
        prescription: WorkoutExercise
    ) async throws -> WorkoutSetLog {
        let insert = SetInsert(
            id: set.id,
            sessionID: sessionID,
            workoutExerciseID: prescription.id,
            exerciseID: prescription.exerciseID,
            setNumber: set.setNumber,
            weight: set.weight,
            reps: set.reps,
            rpe: set.rpe,
            painLevel: set.painLevel,
            notes: set.notes,
            completedAt: Self.timestamp(set.completedAt)
        )
        do {
            let record: SetRecord = try await client
                .from("workout_sets")
                .upsert(insert, onConflict: "id")
                .select()
                .single()
                .execute()
                .value
            return try record.log(exerciseName: prescription.name)
        } catch where Self.isNetworkError(error) {
            let userID = try await client.auth.session.user.id
            try await offlineStore.enqueueSet(
                PendingWorkoutSet(
                    sessionID: sessionID,
                    prescriptionID: prescription.id,
                    log: set
                ),
                userID: userID
            )
            return set
        }
    }

    func finishSession(
        id: UUID,
        startedAt: Date,
        sets: [WorkoutSetLog]
    ) async throws -> WorkoutSessionSummary {
        let completedAt = Date()
        let totalReps = sets.reduce(0) { $0 + $1.reps }
        let totalVolume = sets.reduce(0) {
            $0 + ($1.weight * Double($1.reps))
        }
        let duration = max(
            0,
            Int(completedAt.timeIntervalSince(startedAt))
        )
        let update = SessionFinishUpdate(
            status: "completed",
            completedAt: Self.timestamp(completedAt),
            durationSeconds: duration,
            totalSets: sets.count,
            totalReps: totalReps,
            totalVolume: totalVolume
        )

        do {
            try await client
                .from("workout_sessions")
                .update(update)
                .eq("id", value: id)
                .execute()
        } catch where Self.isNetworkError(error) {
            let userID = try await client.auth.session.user.id
            try await offlineStore.enqueueFinish(
                PendingWorkoutFinish(
                    sessionID: id,
                    startedAt: startedAt,
                    sets: sets
                ),
                userID: userID
            )
        }

        return WorkoutSessionSummary(
            totalVolume: totalVolume,
            totalSets: sets.count,
            totalReps: totalReps,
            durationSeconds: duration,
            personalRecords: []
        )
    }

    func loadPreviousValue(
        exerciseID: UUID
    ) async throws -> PreviousWorkoutValue? {
        let athleteID = try await currentAthleteID()
        let records: [PreviousSetRecord] = try await client
            .from("workout_sets")
            .select(
                "weight,reps,rpe,workout_sessions!inner(athlete_id,status)"
            )
            .eq("exercise_id", value: exerciseID)
            .eq("workout_sessions.athlete_id", value: athleteID)
            .eq("workout_sessions.status", value: "completed")
            .order("completed_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let record = records.first,
              let weight = record.weight,
              let reps = record.reps,
              let rpe = record.rpe else {
            return nil
        }
        return PreviousWorkoutValue(
            weight: weight,
            reps: reps,
            rpe: Int(rpe.rounded())
        )
    }

    private func currentAthleteID() async throws -> UUID {
        let userID = try await client.auth.session.user.id
        let records: [AthleteReference] = try await client
            .from("athletes")
            .select("id")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        guard let id = records.first?.id else {
            throw TrainingRepositoryError.athleteProfileMissing
        }
        return id
    }

    private func loadPrescriptions(
        workoutID: UUID
    ) async throws -> [WorkoutExercise] {
        let records: [PrescriptionRecord] = try await client
            .from("workout_exercises")
            .select(
                "id,exercise_id,sets,reps_min,reps_max,rest_seconds,coach_notes,sort_order,exercises(name,description,category,difficulty)"
            )
            .eq("workout_id", value: workoutID)
            .order("sort_order")
            .execute()
            .value

        return records.map { record in
            let reps: String
            if let minimum = record.repsMin,
               let maximum = record.repsMax,
               minimum != maximum {
                reps = "\(minimum)–\(maximum)"
            } else {
                reps = String(record.repsMin ?? record.repsMax ?? 1)
            }
            return WorkoutExercise(
                id: record.id,
                name: record.exercise.name,
                sets: record.sets,
                reps: reps,
                restSeconds: record.restSeconds,
                coachNotes: record.coachNotes ?? "",
                exerciseID: record.exerciseID,
                exerciseDescription: record.exercise.description,
                category: record.exercise.category,
                difficulty: record.exercise.difficulty
            )
        }
    }

    private func loadSets(
        sessionID: UUID,
        workout: Workout
    ) async throws -> [WorkoutSetLog] {
        let records: [SetRecord] = try await client
            .from("workout_sets")
            .select()
            .eq("session_id", value: sessionID)
            .order("completed_at")
            .execute()
            .value
        return try records.map { record in
            let name = workout.exercises.first {
                $0.exerciseID == record.exerciseID
            }?.name ?? "Exercise"
            return try record.log(exerciseName: name)
        }
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    func synchronizePendingLogs() async throws {
        let userID = try await client.auth.session.user.id
        var remainingSets: [PendingWorkoutSet] = []
        for pending in await offlineStore.pendingSets(userID: userID) {
            let insert = SetInsert(
                id: pending.log.id,
                sessionID: pending.sessionID,
                workoutExerciseID: pending.prescriptionID,
                exerciseID: pending.log.exerciseID,
                setNumber: pending.log.setNumber,
                weight: pending.log.weight,
                reps: pending.log.reps,
                rpe: pending.log.rpe,
                painLevel: pending.log.painLevel,
                notes: pending.log.notes,
                completedAt: Self.timestamp(pending.log.completedAt)
            )
            do {
                try await client.from("workout_sets")
                    .upsert(insert, onConflict: "id")
                    .execute()
            } catch {
                remainingSets.append(pending)
                if !Self.isNetworkError(error) { throw error }
            }
        }
        try await offlineStore.replacePendingSets(
            remainingSets,
            userID: userID
        )
        guard remainingSets.isEmpty else { return }

        var remainingFinishes: [PendingWorkoutFinish] = []
        for pending in await offlineStore.pendingFinishes(userID: userID) {
            let completedAt = pending.sets.map(\.completedAt).max() ?? Date()
            let update = Self.finishUpdate(
                startedAt: pending.startedAt,
                completedAt: completedAt,
                sets: pending.sets
            )
            do {
                try await client.from("workout_sessions")
                    .update(update)
                    .eq("id", value: pending.sessionID)
                    .execute()
            } catch {
                remainingFinishes.append(pending)
                if !Self.isNetworkError(error) { throw error }
            }
        }
        try await offlineStore.replacePendingFinishes(
            remainingFinishes,
            userID: userID
        )
    }

    func hasPendingLogs() async -> Bool {
        guard let userID = try? await client.auth.session.user.id else {
            return false
        }
        let sets = await offlineStore.pendingSets(userID: userID)
        let finishes = await offlineStore.pendingFinishes(userID: userID)
        return !sets.isEmpty || !finishes.isEmpty
    }

    private static func finishUpdate(
        startedAt: Date,
        completedAt: Date,
        sets: [WorkoutSetLog]
    ) -> SessionFinishUpdate {
        SessionFinishUpdate(
            status: "completed",
            completedAt: timestamp(completedAt),
            durationSeconds: max(
                0,
                Int(completedAt.timeIntervalSince(startedAt))
            ),
            totalSets: sets.count,
            totalReps: sets.reduce(0) { $0 + $1.reps },
            totalVolume: sets.reduce(0) {
                $0 + ($1.weight * Double($1.reps))
            }
        )
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        (error as NSError).domain == NSURLErrorDomain
    }

    fileprivate static func parseTimestamp(_ value: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            throw TrainingRepositoryError.invalidTrainingData
        }
        return date
    }
}

private struct AthleteReference: Decodable { let id: UUID }

private struct ActivePlanPayload: Decodable {
    let assignmentID: UUID
    let startsOn: String
    let weeks: [ActivePlanWeek]

    var trainingPlan: TrainingPlan {
        let startDate = Self.dateFormatter.date(from: startsOn) ?? Date()
        let workouts = weeks.flatMap { week in
            week.workouts.map { workout in
                let offset = ((week.weekNumber - 1) * 7)
                    + (workout.dayNumber - 1)
                return Workout(
                    id: workout.id,
                    title: workout.name,
                    description: workout.description ?? "",
                    estimatedDurationMinutes:
                        workout.estimatedDurationMinutes ?? 0,
                    scheduledDate: Calendar.current.date(
                        byAdding: .day,
                        value: offset,
                        to: startDate
                    ) ?? startDate,
                    status: workout.completed ? .completed : .scheduled,
                    exercises: workout.exercises.map(\.workoutExercise),
                    assignmentID: assignmentID
                )
            }
        }
        return TrainingPlan(workouts: workouts)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    enum CodingKeys: String, CodingKey {
        case assignmentID = "assignment_id"
        case startsOn = "starts_on"
        case weeks
    }
}

private struct ActivePlanWeek: Decodable {
    let weekNumber: Int
    let workouts: [ActivePlanWorkout]
    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
        case workouts
    }
}

private struct ActivePlanWorkout: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let dayNumber: Int
    let estimatedDurationMinutes: Int?
    let completed: Bool
    let exercises: [ActivePlanExercise]
    enum CodingKeys: String, CodingKey {
        case id, name, description, completed, exercises
        case dayNumber = "day_number"
        case estimatedDurationMinutes = "estimated_duration_minutes"
    }
}

private struct ActivePlanExercise: Decodable {
    let id: UUID
    let exerciseID: UUID
    let name: String
    let description: String?
    let category: String?
    let difficulty: String?
    let sets: Int
    let repsMin: Int?
    let repsMax: Int?
    let restSeconds: Int
    let coachNotes: String?

    var workoutExercise: WorkoutExercise {
        let reps: String
        if let repsMin, let repsMax, repsMin != repsMax {
            reps = "\(repsMin)–\(repsMax)"
        } else {
            reps = String(repsMin ?? repsMax ?? 1)
        }
        return WorkoutExercise(
            id: id,
            name: name,
            sets: sets,
            reps: reps,
            restSeconds: restSeconds,
            coachNotes: coachNotes ?? "",
            exerciseID: exerciseID,
            exerciseDescription: description,
            category: category,
            difficulty: difficulty
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, difficulty, sets
        case exerciseID = "exercise_id"
        case repsMin = "reps_min"
        case repsMax = "reps_max"
        case restSeconds = "rest_seconds"
        case coachNotes = "coach_notes"
    }
}

private struct AssignmentRecord: Decodable {
    let id: UUID
    let programID: UUID
    let startsOn: String
    var startsOnDate: Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: startsOn) ?? Date()
    }
    enum CodingKeys: String, CodingKey {
        case id
        case programID = "program_id"
        case startsOn = "starts_on"
    }
}

private struct WeekRecord: Decodable {
    let id: UUID
    let weekNumber: Int
    enum CodingKeys: String, CodingKey {
        case id
        case weekNumber = "week_number"
    }
}

private struct WorkoutRecord: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let dayNumber: Int
    let estimatedDurationMinutes: Int?
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case dayNumber = "day_number"
        case estimatedDurationMinutes = "estimated_duration_minutes"
    }
}

private struct PrescriptionRecord: Decodable {
    let id: UUID
    let exerciseID: UUID
    let sets: Int
    let repsMin: Int?
    let repsMax: Int?
    let restSeconds: Int
    let coachNotes: String?
    let exercise: ExerciseNameRecord
    enum CodingKeys: String, CodingKey {
        case id, sets
        case exerciseID = "exercise_id"
        case repsMin = "reps_min"
        case repsMax = "reps_max"
        case restSeconds = "rest_seconds"
        case coachNotes = "coach_notes"
        case exercise = "exercises"
    }
}

private struct ExerciseNameRecord: Decodable {
    let name: String
    let description: String?
    let category: String?
    let difficulty: String?
}

private struct SessionStatusRecord: Decodable {
    let workoutID: UUID?
    enum CodingKeys: String, CodingKey {
        case workoutID = "workout_id"
    }
}

private struct SessionRecord: Decodable {
    let id: UUID
    let startedAt: String
    enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
    }
}

private struct SessionInsert: Encodable {
    let athleteID: UUID
    let assignmentID: UUID
    let workoutID: UUID
    let status: String
    let startedAt: String
    enum CodingKeys: String, CodingKey {
        case athleteID = "athlete_id"
        case assignmentID = "assignment_id"
        case workoutID = "workout_id"
        case status
        case startedAt = "started_at"
    }
}

private struct SetInsert: Encodable {
    let id: UUID
    let sessionID: UUID
    let workoutExerciseID: UUID
    let exerciseID: UUID
    let setNumber: Int
    let weight: Double
    let reps: Int
    let rpe: Int
    let painLevel: Int
    let notes: String
    let completedAt: String
    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case workoutExerciseID = "workout_exercise_id"
        case exerciseID = "exercise_id"
        case setNumber = "set_number"
        case weight, reps, rpe, notes
        case painLevel = "pain_level"
        case completedAt = "completed_at"
    }
}

private struct SetRecord: Decodable {
    let id: UUID
    let exerciseID: UUID
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let rpe: Double?
    let painLevel: Int?
    let notes: String?
    let completedAt: String
    func log(exerciseName: String) throws -> WorkoutSetLog {
        WorkoutSetLog(
            id: id,
            exerciseID: exerciseID,
            exerciseName: exerciseName,
            setNumber: setNumber,
            weight: weight ?? 0,
            reps: reps ?? 0,
            rpe: Int((rpe ?? 1).rounded()),
            painLevel: painLevel ?? 1,
            notes: notes ?? "",
            completedAt: try TrainingRepository.parseTimestamp(completedAt)
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, weight, reps, rpe, notes
        case exerciseID = "exercise_id"
        case setNumber = "set_number"
        case painLevel = "pain_level"
        case completedAt = "completed_at"
    }
}

private struct PreviousSetRecord: Decodable {
    let weight: Double?
    let reps: Int?
    let rpe: Double?
}

private struct SessionFinishUpdate: Encodable {
    let status: String
    let completedAt: String
    let durationSeconds: Int
    let totalSets: Int
    let totalReps: Int
    let totalVolume: Double
    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case durationSeconds = "duration_seconds"
        case totalSets = "total_sets"
        case totalReps = "total_reps"
        case totalVolume = "total_volume"
    }
}
