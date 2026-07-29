import Foundation
import Supabase

struct TrainingPlan {
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

final class TrainingRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadActiveTrainingPlan() async throws -> TrainingPlan {
        let athleteID = try await currentAthleteID()
        let assignments: [AssignmentRecord] = try await client
            .from("athlete_program_assignments")
            .select("*,workout_programs!inner(status)")
            .eq("athlete_id", value: athleteID)
            .eq("status", value: "active")
            .eq("workout_programs.status", value: "active")
            .order("starts_on", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let assignment = assignments.first else {
            throw TrainingRepositoryError.activeAssignmentMissing
        }

        let weeks: [WeekRecord] = try await client
            .from("workout_program_weeks")
            .select()
            .eq("program_id", value: assignment.programID)
            .order("week_number")
            .execute()
            .value

        let completed: [SessionStatusRecord] = try await client
            .from("workout_sessions")
            .select("workout_id,status")
            .eq("athlete_id", value: athleteID)
            .eq("status", value: "completed")
            .execute()
            .value
        let completedWorkoutIDs = Set(completed.compactMap(\.workoutID))

        var workouts: [Workout] = []
        for week in weeks {
            let weekWorkouts: [WorkoutRecord] = try await client
                .from("workouts")
                .select()
                .eq("program_week_id", value: week.id)
                .order("day_number")
                .order("sort_order")
                .execute()
                .value

            for workout in weekWorkouts {
                let prescriptions = try await loadPrescriptions(
                    workoutID: workout.id
                )
                let dayOffset = ((week.weekNumber - 1) * 7)
                    + (workout.dayNumber - 1)
                let scheduledDate = Calendar.current.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: assignment.startsOnDate
                ) ?? assignment.startsOnDate

                workouts.append(
                    Workout(
                        id: workout.id,
                        title: workout.name,
                        description: workout.description ?? "",
                        estimatedDurationMinutes:
                            workout.estimatedDurationMinutes ?? 0,
                        scheduledDate: scheduledDate,
                        status: completedWorkoutIDs.contains(workout.id)
                            ? .completed
                            : .scheduled,
                        exercises: prescriptions,
                        assignmentID: assignment.id
                    )
                )
            }
        }

        return TrainingPlan(workouts: workouts)
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
        let record: SetRecord = try await client
            .from("workout_sets")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        return try record.log(
            exerciseName: prescription.name
        )
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

        try await client
            .from("workout_sessions")
            .update(update)
            .eq("id", value: id)
            .execute()

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

    fileprivate static func parseTimestamp(_ value: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            throw TrainingRepositoryError.invalidTrainingData
        }
        return date
    }
}

private struct AthleteReference: Decodable { let id: UUID }

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
