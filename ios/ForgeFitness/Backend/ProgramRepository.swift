import Foundation
import Supabase

enum ProgramRepositoryError: LocalizedError {
    case emptyProgram
    case unpublishedProgram
    case duplicateAssignment
    case protectedProgram

    var errorDescription: String? {
        switch self {
        case .emptyProgram:
            "Add at least one week, workout, and exercise before publishing."
        case .unpublishedProgram:
            "Publish this program before assigning athletes."
        case .duplicateAssignment:
            "This athlete already has this program assigned."
        case .protectedProgram:
            "Published programs with active assignments cannot be deleted."
        }
    }
}

final class ProgramRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func isCurrentUserCoach() async -> Bool {
        do {
            let userID = try await client.auth.session.user.id
            let records: [CoachReference] = try await client
                .from("coaches")
                .select("user_id")
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            return !records.isEmpty
        } catch {
            return false
        }
    }

    func loadPrograms() async throws -> [TrainingProgram] {
        let coachID = try await client.auth.session.user.id
        let records: [ProgramRecord] = try await client
            .from("workout_programs")
            .select()
            .eq("coach_user_id", value: coachID)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return records.map { $0.program(weeks: []) }
    }

    func loadProgram(id: UUID) async throws -> TrainingProgram {
        let records: [ProgramRecord] = try await client
            .from("workout_programs")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        guard let record = records.first else {
            throw TrainingRepositoryError.invalidTrainingData
        }

        let weekRecords: [ProgramWeekRecord] = try await client
            .from("workout_program_weeks")
            .select()
            .eq("program_id", value: id)
            .order("week_number")
            .execute()
            .value
        var weeks: [TrainingProgramWeek] = []
        for week in weekRecords {
            weeks.append(
                TrainingProgramWeek(
                    id: week.id,
                    weekNumber: week.weekNumber,
                    name: week.name ?? "Week \(week.weekNumber)",
                    focus: week.focus ?? "",
                    workouts: try await loadWorkouts(weekID: week.id)
                )
            )
        }
        return record.program(weeks: weeks)
    }

    func createProgram() async throws -> TrainingProgram {
        let insert = ProgramInsert(
            coachUserID: try await client.auth.session.user.id,
            name: "Untitled Program",
            description: "",
            status: TrainingProgramStatus.draft.rawValue,
            durationWeeks: 1
        )
        let record: ProgramRecord = try await client
            .from("workout_programs")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        return record.program(weeks: [])
    }

    func updateProgram(_ program: TrainingProgram) async throws {
        try await client
            .from("workout_programs")
            .update(
                ProgramUpdate(
                    name: program.name,
                    description: program.description,
                    durationWeeks: max(1, program.weeks.count)
                )
            )
            .eq("id", value: program.id)
            .execute()
    }

    func setStatus(
        _ status: TrainingProgramStatus,
        for program: TrainingProgram
    ) async throws {
        if status == .published, !isPublishable(program) {
            throw ProgramRepositoryError.emptyProgram
        }
        try await client
            .from("workout_programs")
            .update(ProgramStatusUpdate(status: status.rawValue))
            .eq("id", value: program.id)
            .execute()
    }

    func deleteProgram(_ program: TrainingProgram) async throws {
        if program.status == .published,
           try await hasActiveAssignments(programID: program.id) {
            throw ProgramRepositoryError.protectedProgram
        }
        try await client
            .from("workout_programs")
            .delete()
            .eq("id", value: program.id)
            .execute()
    }

    func duplicateProgram(_ source: TrainingProgram) async throws -> UUID {
        let fullSource = try await loadProgram(id: source.id)
        var duplicate = try await createProgram()
        duplicate.name = "\(fullSource.name) Copy"
        duplicate.description = fullSource.description
        try await updateProgram(duplicate)

        for sourceWeek in fullSource.weeks {
            let week = try await addWeek(
                programID: duplicate.id,
                number: sourceWeek.weekNumber,
                name: sourceWeek.name
            )
            for sourceWorkout in sourceWeek.workouts {
                let workout = try await addWorkout(
                    weekID: week.id,
                    dayNumber: sourceWorkout.dayNumber,
                    sortOrder: sourceWorkout.sortOrder,
                    name: sourceWorkout.name
                )
                var editableWorkout = workout
                editableWorkout.description = sourceWorkout.description
                editableWorkout.estimatedDurationMinutes =
                    sourceWorkout.estimatedDurationMinutes
                try await updateWorkout(editableWorkout)
                for exercise in sourceWorkout.exercises {
                    _ = try await addExercise(
                        workoutID: workout.id,
                        exerciseID: exercise.exerciseID,
                        order: exercise.sortOrder,
                        values: exercise
                    )
                }
            }
        }
        duplicate.durationWeeks = max(1, fullSource.weeks.count)
        try await updateProgram(duplicate)
        return duplicate.id
    }

    func addWeek(
        programID: UUID,
        number: Int,
        name: String? = nil
    ) async throws -> TrainingProgramWeek {
        let record: ProgramWeekRecord = try await client
            .from("workout_program_weeks")
            .insert(
                ProgramWeekInsert(
                    programID: programID,
                    weekNumber: number,
                    name: name ?? "Week \(number)",
                    focus: ""
                )
            )
            .select()
            .single()
            .execute()
            .value
        return TrainingProgramWeek(
            id: record.id,
            weekNumber: record.weekNumber,
            name: record.name ?? "Week \(record.weekNumber)",
            focus: record.focus ?? "",
            workouts: []
        )
    }

    func updateWeek(_ week: TrainingProgramWeek) async throws {
        try await client
            .from("workout_program_weeks")
            .update(
                ProgramWeekUpdate(
                    weekNumber: week.weekNumber,
                    name: week.name,
                    focus: week.focus
                )
            )
            .eq("id", value: week.id)
            .execute()
    }

    func reorderWeeks(_ weeks: [TrainingProgramWeek]) async throws {
        for (index, week) in weeks.enumerated() {
            try await client
                .from("workout_program_weeks")
                .update(OrderUpdate(value: index + 10_000))
                .eq("id", value: week.id)
                .execute()
        }
        for (index, week) in weeks.enumerated() {
            try await client
                .from("workout_program_weeks")
                .update(WeekOrderUpdate(weekNumber: index + 1))
                .eq("id", value: week.id)
                .execute()
        }
    }

    func deleteWeek(id: UUID) async throws {
        try await client
            .from("workout_program_weeks")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func addWorkout(
        weekID: UUID,
        dayNumber: Int,
        sortOrder: Int,
        name: String = "Untitled Workout"
    ) async throws -> ProgramWorkout {
        let record: ProgramWorkoutRecord = try await client
            .from("workouts")
            .insert(
                ProgramWorkoutInsert(
                    weekID: weekID,
                    name: name,
                    description: "",
                    dayNumber: dayNumber,
                    estimatedDurationMinutes: 45,
                    sortOrder: sortOrder
                )
            )
            .select()
            .single()
            .execute()
            .value
        return record.workout(exercises: [])
    }

    func updateWorkout(_ workout: ProgramWorkout) async throws {
        try await client
            .from("workouts")
            .update(
                ProgramWorkoutUpdate(
                    name: workout.name,
                    description: workout.description,
                    dayNumber: workout.dayNumber,
                    estimatedDurationMinutes:
                        workout.estimatedDurationMinutes,
                    sortOrder: workout.sortOrder
                )
            )
            .eq("id", value: workout.id)
            .execute()
    }

    func reorderWorkouts(_ workouts: [ProgramWorkout]) async throws {
        for (index, workout) in workouts.enumerated() {
            try await client
                .from("workouts")
                .update(WorkoutOrderUpdate(sortOrder: index + 10_000))
                .eq("id", value: workout.id)
                .execute()
        }
        for (index, workout) in workouts.enumerated() {
            try await client
                .from("workouts")
                .update(WorkoutOrderUpdate(sortOrder: index))
                .eq("id", value: workout.id)
                .execute()
        }
    }

    func deleteWorkout(id: UUID) async throws {
        try await client
            .from("workouts")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func loadExerciseChoices() async throws -> [ProgramExerciseChoice] {
        let records: [ExerciseChoiceRecord] = try await client
            .from("exercises")
            .select("id,name,category,difficulty")
            .eq("is_active", value: true)
            .order("name")
            .execute()
            .value
        return records.map(\.choice)
    }

    func addExercise(
        workoutID: UUID,
        exerciseID: UUID,
        order: Int,
        values: ProgramExercise? = nil
    ) async throws -> ProgramExercise {
        let insert = PrescriptionInsert(
            workoutID: workoutID,
            exerciseID: exerciseID,
            sortOrder: order,
            sets: values?.sets ?? 3,
            repsMin: values?.repsMin ?? 8,
            repsMax: values?.repsMax ?? 8,
            restSeconds: values?.restSeconds ?? 60,
            tempo: values?.tempo ?? "",
            notes: values?.notes ?? "",
            coachCues: values?.coachCues ?? ""
        )
        let record: PrescriptionRecord = try await client
            .from("workout_exercises")
            .insert(insert)
            .select(
                "id,exercise_id,sets,reps_min,reps_max,rest_seconds,tempo,coach_notes,coach_cues,sort_order,exercises(name)"
            )
            .single()
            .execute()
            .value
        return record.exercise
    }

    func updateExercise(_ exercise: ProgramExercise) async throws {
        try await client
            .from("workout_exercises")
            .update(
                PrescriptionUpdate(
                    sets: exercise.sets,
                    repsMin: exercise.repsMin,
                    repsMax: exercise.repsMax,
                    restSeconds: exercise.restSeconds,
                    tempo: exercise.tempo,
                    notes: exercise.notes,
                    coachCues: exercise.coachCues,
                    sortOrder: exercise.sortOrder
                )
            )
            .eq("id", value: exercise.id)
            .execute()
    }

    func reorderExercises(_ exercises: [ProgramExercise]) async throws {
        for (index, exercise) in exercises.enumerated() {
            try await client
                .from("workout_exercises")
                .update(WorkoutOrderUpdate(sortOrder: index + 10_000))
                .eq("id", value: exercise.id)
                .execute()
        }
        for (index, exercise) in exercises.enumerated() {
            try await client
                .from("workout_exercises")
                .update(WorkoutOrderUpdate(sortOrder: index))
                .eq("id", value: exercise.id)
                .execute()
        }
    }

    func deleteExercise(id: UUID) async throws {
        try await client
            .from("workout_exercises")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func loadAssignableAthletes(
        programID: UUID
    ) async throws -> [ProgramAthlete] {
        let athleteRecords: [AssignableAthleteRecord] = try await client
            .rpc("get_assignable_athletes")
            .execute()
            .value
        let assignmentRecords: [AssignmentRecord] = try await client
            .from("athlete_program_assignments")
            .select()
            .eq("program_id", value: programID)
            .execute()
            .value
        let current = Dictionary(
            uniqueKeysWithValues: assignmentRecords
                .filter { $0.status == "active" || $0.status == "scheduled" }
                .map { ($0.athleteID, $0.id) }
        )
        return athleteRecords.map {
            $0.athlete(assignmentID: current[$0.id])
        }
    }

    func assign(
        athleteID: UUID,
        to program: TrainingProgram
    ) async throws {
        guard program.status == .published else {
            throw ProgramRepositoryError.unpublishedProgram
        }
        guard !(try await hasAssignment(
            athleteID: athleteID,
            programID: program.id
        )) else {
            throw ProgramRepositoryError.duplicateAssignment
        }
        let coachID = try await client.auth.session.user.id
        let today = Self.date(Date())
        try await client
            .from("athlete_program_assignments")
            .insert(
                AssignmentInsert(
                    athleteID: athleteID,
                    programID: program.id,
                    assignedBy: coachID,
                    startsOn: today,
                    status: "active"
                )
            )
            .execute()
    }

    func removeAssignment(id: UUID) async throws {
        try await client
            .from("athlete_program_assignments")
            .update(AssignmentStatusUpdate(status: "cancelled"))
            .eq("id", value: id)
            .execute()
    }

    private func loadWorkouts(
        weekID: UUID
    ) async throws -> [ProgramWorkout] {
        let records: [ProgramWorkoutRecord] = try await client
            .from("workouts")
            .select()
            .eq("program_week_id", value: weekID)
            .order("sort_order")
            .execute()
            .value
        var workouts: [ProgramWorkout] = []
        for record in records {
            workouts.append(
                record.workout(
                    exercises: try await loadExercises(
                        workoutID: record.id
                    )
                )
            )
        }
        return workouts
    }

    private func loadExercises(
        workoutID: UUID
    ) async throws -> [ProgramExercise] {
        let records: [PrescriptionRecord] = try await client
            .from("workout_exercises")
            .select(
                "id,exercise_id,sets,reps_min,reps_max,rest_seconds,tempo,coach_notes,coach_cues,sort_order,exercises(name)"
            )
            .eq("workout_id", value: workoutID)
            .order("sort_order")
            .execute()
            .value
        return records.map(\.exercise)
    }

    private func isPublishable(_ program: TrainingProgram) -> Bool {
        !program.weeks.isEmpty
            && program.weeks.allSatisfy {
                !$0.workouts.isEmpty
                    && $0.workouts.allSatisfy { !$0.exercises.isEmpty }
            }
    }

    private func hasActiveAssignments(programID: UUID) async throws -> Bool {
        let records: [AssignmentRecord] = try await client
            .from("athlete_program_assignments")
            .select("id,athlete_id,status")
            .eq("program_id", value: programID)
            .execute()
            .value
        return records.contains {
            $0.status == "active" || $0.status == "scheduled"
        }
    }

    private func hasAssignment(
        athleteID: UUID,
        programID: UUID
    ) async throws -> Bool {
        let records: [AssignmentRecord] = try await client
            .from("athlete_program_assignments")
            .select("id,athlete_id,status")
            .eq("program_id", value: programID)
            .eq("athlete_id", value: athleteID)
            .execute()
            .value
        return records.contains {
            $0.status == "active" || $0.status == "scheduled"
        }
    }

    private static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct ProgramRecord: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let status: String
    let durationWeeks: Int
    func program(weeks: [TrainingProgramWeek]) -> TrainingProgram {
        TrainingProgram(
            id: id,
            name: name,
            description: description ?? "",
            status: TrainingProgramStatus(rawValue: status) ?? .draft,
            durationWeeks: durationWeeks,
            weeks: weeks
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case durationWeeks = "duration_weeks"
    }
}

private struct CoachReference: Decodable {
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

private struct ProgramInsert: Encodable {
    let coachUserID: UUID
    let name: String
    let description: String
    let status: String
    let durationWeeks: Int
    enum CodingKeys: String, CodingKey {
        case coachUserID = "coach_user_id"
        case name, description, status
        case durationWeeks = "duration_weeks"
    }
}

private struct ProgramUpdate: Encodable {
    let name: String
    let description: String
    let durationWeeks: Int
    enum CodingKeys: String, CodingKey {
        case name, description
        case durationWeeks = "duration_weeks"
    }
}

private struct ProgramStatusUpdate: Encodable { let status: String }

private struct ProgramWeekRecord: Decodable {
    let id: UUID
    let weekNumber: Int
    let name: String?
    let focus: String?
    enum CodingKeys: String, CodingKey {
        case id, name, focus
        case weekNumber = "week_number"
    }
}

private struct ProgramWeekInsert: Encodable {
    let programID: UUID
    let weekNumber: Int
    let name: String
    let focus: String
    enum CodingKeys: String, CodingKey {
        case programID = "program_id"
        case weekNumber = "week_number"
        case name, focus
    }
}

private struct ProgramWeekUpdate: Encodable {
    let weekNumber: Int
    let name: String
    let focus: String
    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
        case name, focus
    }
}

private struct WeekOrderUpdate: Encodable {
    let weekNumber: Int
    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
    }
}

private struct OrderUpdate: Encodable {
    let value: Int
    enum CodingKeys: String, CodingKey {
        case value = "week_number"
    }
}

private struct ProgramWorkoutRecord: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let dayNumber: Int
    let estimatedDurationMinutes: Int?
    let sortOrder: Int
    func workout(exercises: [ProgramExercise]) -> ProgramWorkout {
        ProgramWorkout(
            id: id,
            name: name,
            description: description ?? "",
            dayNumber: dayNumber,
            estimatedDurationMinutes: estimatedDurationMinutes ?? 45,
            sortOrder: sortOrder,
            exercises: exercises
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case dayNumber = "day_number"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case sortOrder = "sort_order"
    }
}

private struct ProgramWorkoutInsert: Encodable {
    let weekID: UUID
    let name: String
    let description: String
    let dayNumber: Int
    let estimatedDurationMinutes: Int
    let sortOrder: Int
    enum CodingKeys: String, CodingKey {
        case weekID = "program_week_id"
        case name, description
        case dayNumber = "day_number"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case sortOrder = "sort_order"
    }
}

private struct ProgramWorkoutUpdate: Encodable {
    let name: String
    let description: String
    let dayNumber: Int
    let estimatedDurationMinutes: Int
    let sortOrder: Int
    enum CodingKeys: String, CodingKey {
        case name, description
        case dayNumber = "day_number"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case sortOrder = "sort_order"
    }
}

private struct WorkoutOrderUpdate: Encodable {
    let sortOrder: Int
    enum CodingKeys: String, CodingKey {
        case sortOrder = "sort_order"
    }
}

private struct ExerciseChoiceRecord: Decodable {
    let id: UUID
    let name: String
    let category: String
    let difficulty: String?
    var choice: ProgramExerciseChoice {
        ProgramExerciseChoice(
            id: id,
            name: name,
            category: category,
            difficulty: difficulty ?? "Not specified"
        )
    }
}

private struct PrescriptionRecord: Decodable {
    let id: UUID
    let exerciseID: UUID
    let sets: Int
    let repsMin: Int?
    let repsMax: Int?
    let restSeconds: Int
    let tempo: String?
    let notes: String?
    let coachCues: String?
    let sortOrder: Int
    let exerciseName: ExerciseNameRecord
    var exercise: ProgramExercise {
        ProgramExercise(
            id: id,
            exerciseID: exerciseID,
            name: exerciseName.name,
            sets: sets,
            repsMin: repsMin ?? 1,
            repsMax: repsMax ?? repsMin ?? 1,
            restSeconds: restSeconds,
            tempo: tempo ?? "",
            notes: notes ?? "",
            coachCues: coachCues ?? "",
            sortOrder: sortOrder
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, sets, tempo
        case exerciseID = "exercise_id"
        case repsMin = "reps_min"
        case repsMax = "reps_max"
        case restSeconds = "rest_seconds"
        case notes = "coach_notes"
        case coachCues = "coach_cues"
        case sortOrder = "sort_order"
        case exerciseName = "exercises"
    }
}

private struct ExerciseNameRecord: Decodable { let name: String }

private struct PrescriptionInsert: Encodable {
    let workoutID: UUID
    let exerciseID: UUID
    let sortOrder: Int
    let sets: Int
    let repsMin: Int
    let repsMax: Int
    let restSeconds: Int
    let tempo: String
    let notes: String
    let coachCues: String
    enum CodingKeys: String, CodingKey {
        case workoutID = "workout_id"
        case exerciseID = "exercise_id"
        case sortOrder = "sort_order"
        case sets
        case repsMin = "reps_min"
        case repsMax = "reps_max"
        case restSeconds = "rest_seconds"
        case tempo
        case notes = "coach_notes"
        case coachCues = "coach_cues"
    }
}

private struct PrescriptionUpdate: Encodable {
    let sets: Int
    let repsMin: Int
    let repsMax: Int
    let restSeconds: Int
    let tempo: String
    let notes: String
    let coachCues: String
    let sortOrder: Int
    enum CodingKeys: String, CodingKey {
        case sets, tempo
        case repsMin = "reps_min"
        case repsMax = "reps_max"
        case restSeconds = "rest_seconds"
        case notes = "coach_notes"
        case coachCues = "coach_cues"
        case sortOrder = "sort_order"
    }
}

private struct AssignableAthleteRecord: Decodable {
    let id: UUID
    let firstName: String?
    let lastName: String?
    let team: String?
    let position: String?
    let graduationYear: Int?
    func athlete(assignmentID: UUID?) -> ProgramAthlete {
        ProgramAthlete(
            id: id,
            name: "\(firstName ?? "") \(lastName ?? "")"
                .trimmingCharacters(in: .whitespaces),
            team: team ?? "No team",
            position: position ?? "Not specified",
            graduationYear: graduationYear ?? 0,
            assignmentID: assignmentID
        )
    }
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case team, position
        case graduationYear = "graduation_year"
    }
}

private struct AssignmentRecord: Decodable {
    let id: UUID
    let athleteID: UUID
    let status: String
    enum CodingKeys: String, CodingKey {
        case id, status
        case athleteID = "athlete_id"
    }
}

private struct AssignmentInsert: Encodable {
    let athleteID: UUID
    let programID: UUID
    let assignedBy: UUID
    let startsOn: String
    let status: String
    enum CodingKeys: String, CodingKey {
        case athleteID = "athlete_id"
        case programID = "program_id"
        case assignedBy = "assigned_by"
        case startsOn = "starts_on"
        case status
    }
}

private struct AssignmentStatusUpdate: Encodable { let status: String }
