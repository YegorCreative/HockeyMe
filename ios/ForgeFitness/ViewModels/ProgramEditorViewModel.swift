import Combine
import Foundation

@MainActor
final class ProgramEditorViewModel: ObservableObject {
    @Published var program: TrainingProgram?
    @Published private(set) var exerciseChoices: [ProgramExerciseChoice] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    let repository: ProgramRepository
    private let programID: UUID

    init(programID: UUID, repository: ProgramRepository) {
        self.programID = programID
        self.repository = repository
    }

    var canPublish: Bool {
        guard let program else { return false }
        return !program.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
            && !program.weeks.isEmpty
            && program.weeks.allSatisfy {
                !$0.workouts.isEmpty
                    && $0.workouts.allSatisfy {
                        !$0.exercises.isEmpty
                    }
            }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let loadedProgram = repository.loadProgram(id: programID)
            async let choices = repository.loadExerciseChoices()
            program = try await loadedProgram
            exerciseChoices = try await choices
        } catch {
            errorMessage = friendly(error)
        }
        isLoading = false
    }

    func saveProgram() async {
        guard let program else { return }
        await save {
            try await repository.updateProgram(program)
        }
    }

    func setPublished(_ published: Bool) async {
        guard let program else { return }
        await save {
            try await repository.setStatus(
                published ? .published : .draft,
                for: program
            )
            self.program?.status = published ? .published : .draft
        }
    }

    func addWeek() async {
        guard let program else { return }
        await save {
            let week = try await repository.addWeek(
                programID: program.id,
                number: program.weeks.count + 1
            )
            self.program?.weeks.append(week)
            self.program?.durationWeeks =
                self.program?.weeks.count ?? 1
            if let updatedProgram = self.program {
                try await repository.updateProgram(updatedProgram)
            }
        }
    }

    func saveWeek(_ week: TrainingProgramWeek) async {
        await save {
            try await repository.updateWeek(week)
            replaceWeek(week)
        }
    }

    func deleteWeek(_ week: TrainingProgramWeek) async {
        await save {
            try await repository.deleteWeek(id: week.id)
            self.program?.weeks.removeAll { $0.id == week.id }
            await self.persistWeekOrder()
            if let updatedProgram = self.program {
                try await repository.updateProgram(updatedProgram)
            }
        }
    }

    func moveWeek(_ week: TrainingProgramWeek, by offset: Int) async {
        guard var weeks = program?.weeks,
              let source = weeks.firstIndex(where: { $0.id == week.id }) else {
            return
        }
        let destination = source + offset
        guard weeks.indices.contains(destination) else { return }
        weeks.swapAt(source, destination)
        program?.weeks = weeks
        await save {
            try await repository.reorderWeeks(weeks)
            for index in weeks.indices {
                self.program?.weeks[index].weekNumber = index + 1
            }
        }
    }

    func addWorkout(to week: TrainingProgramWeek) async {
        await save {
            let workout = try await repository.addWorkout(
                weekID: week.id,
                dayNumber: week.workouts.count + 1,
                sortOrder: week.workouts.count
            )
            guard let index = self.program?.weeks.firstIndex(
                where: { $0.id == week.id }
            ) else { return }
            self.program?.weeks[index].workouts.append(workout)
        }
    }

    func saveWorkout(
        _ workout: ProgramWorkout,
        weekID: UUID
    ) async {
        await save {
            try await repository.updateWorkout(workout)
            replaceWorkout(workout, weekID: weekID)
        }
    }

    func deleteWorkout(
        _ workout: ProgramWorkout,
        weekID: UUID
    ) async {
        await save {
            try await repository.deleteWorkout(id: workout.id)
            guard let weekIndex = self.program?.weeks.firstIndex(
                where: { $0.id == weekID }
            ) else { return }
            self.program?.weeks[weekIndex].workouts.removeAll {
                $0.id == workout.id
            }
        }
    }

    func moveWorkout(
        _ workout: ProgramWorkout,
        weekID: UUID,
        by offset: Int
    ) async {
        guard let weekIndex = program?.weeks.firstIndex(
            where: { $0.id == weekID }
        ), var workouts = program?.weeks[weekIndex].workouts,
        let source = workouts.firstIndex(where: { $0.id == workout.id }) else {
            return
        }
        let destination = source + offset
        guard workouts.indices.contains(destination) else { return }
        workouts.swapAt(source, destination)
        program?.weeks[weekIndex].workouts = workouts
        await save {
            try await repository.reorderWorkouts(workouts)
            for index in workouts.indices {
                self.program?.weeks[weekIndex]
                    .workouts[index].sortOrder = index
            }
        }
    }

    func addExercise(
        _ choice: ProgramExerciseChoice,
        workoutID: UUID,
        weekID: UUID
    ) async {
        guard let workout = workout(
            id: workoutID,
            weekID: weekID
        ) else { return }
        await save {
            let exercise = try await repository.addExercise(
                workoutID: workoutID,
                exerciseID: choice.id,
                order: workout.exercises.count
            )
            guard let location = workoutLocation(
                workoutID: workoutID,
                weekID: weekID
            ) else { return }
            self.program?.weeks[location.week]
                .workouts[location.workout].exercises.append(exercise)
        }
    }

    func saveExercise(
        _ exercise: ProgramExercise,
        workoutID: UUID,
        weekID: UUID
    ) async {
        await save {
            try await repository.updateExercise(exercise)
            guard let location = workoutLocation(
                workoutID: workoutID,
                weekID: weekID
            ), let index = self.program?.weeks[location.week]
                .workouts[location.workout].exercises.firstIndex(
                    where: { $0.id == exercise.id }
                ) else { return }
            self.program?.weeks[location.week]
                .workouts[location.workout].exercises[index] = exercise
        }
    }

    func deleteExercise(
        _ exercise: ProgramExercise,
        workoutID: UUID,
        weekID: UUID
    ) async {
        await save {
            try await repository.deleteExercise(id: exercise.id)
            guard let location = workoutLocation(
                workoutID: workoutID,
                weekID: weekID
            ) else { return }
            self.program?.weeks[location.week]
                .workouts[location.workout].exercises.removeAll {
                    $0.id == exercise.id
                }
        }
    }

    func moveExercise(
        _ exercise: ProgramExercise,
        workoutID: UUID,
        weekID: UUID,
        by offset: Int
    ) async {
        guard let location = workoutLocation(
            workoutID: workoutID,
            weekID: weekID
        ), var exercises = program?.weeks[location.week]
            .workouts[location.workout].exercises,
        let source = exercises.firstIndex(
            where: { $0.id == exercise.id }
        ) else { return }
        let destination = source + offset
        guard exercises.indices.contains(destination) else { return }
        exercises.swapAt(source, destination)
        program?.weeks[location.week]
            .workouts[location.workout].exercises = exercises
        await save {
            try await repository.reorderExercises(exercises)
            for index in exercises.indices {
                self.program?.weeks[location.week]
                    .workouts[location.workout]
                    .exercises[index].sortOrder = index
            }
        }
    }

    private func save(_ operation: () async throws -> Void) async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = friendly(error)
        }
        isSaving = false
    }

    private func persistWeekOrder() async {
        guard let weeks = program?.weeks else { return }
        do {
            try await repository.reorderWeeks(weeks)
        } catch {
            errorMessage = friendly(error)
        }
    }

    private func replaceWeek(_ week: TrainingProgramWeek) {
        guard let index = program?.weeks.firstIndex(
            where: { $0.id == week.id }
        ) else { return }
        program?.weeks[index] = week
    }

    private func replaceWorkout(
        _ workout: ProgramWorkout,
        weekID: UUID
    ) {
        guard let location = workoutLocation(
            workoutID: workout.id,
            weekID: weekID
        ) else { return }
        program?.weeks[location.week].workouts[location.workout] = workout
    }

    private func workout(
        id: UUID,
        weekID: UUID
    ) -> ProgramWorkout? {
        guard let location = workoutLocation(
            workoutID: id,
            weekID: weekID
        ) else { return nil }
        return program?.weeks[location.week].workouts[location.workout]
    }

    private func workoutLocation(
        workoutID: UUID,
        weekID: UUID
    ) -> (week: Int, workout: Int)? {
        guard let weekIndex = program?.weeks.firstIndex(
            where: { $0.id == weekID }
        ), let workoutIndex = program?.weeks[weekIndex]
            .workouts.firstIndex(where: { $0.id == workoutID }) else {
            return nil
        }
        return (weekIndex, workoutIndex)
    }

    private func friendly(_ error: Error) -> String {
        (error as NSError).domain == NSURLErrorDomain
            ? "You're offline. Check your connection and try again."
            : error.localizedDescription
    }
}
