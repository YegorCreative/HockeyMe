import Combine
import Foundation

enum WorkoutSessionPhase {
    case ready
    case active
    case summary
}

@MainActor
final class WorkoutSessionViewModel: ObservableObject {
    @Published private(set) var phase = WorkoutSessionPhase.ready
    @Published private(set) var currentExerciseIndex = 0
    @Published var weight = ""
    @Published var reps = ""
    @Published var rpe = 7
    @Published var painLevel = 1
    @Published var notes = ""
    @Published private(set) var completedSets: [WorkoutSetLog] = []
    @Published private(set) var restSecondsRemaining = 0
    @Published private(set) var isResting = false
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var summary: WorkoutSessionSummary?
    @Published private(set) var previousWorkoutValue: PreviousWorkoutValue?
    @Published private(set) var syncStatusMessage: String?

    let workout: Workout

    private let repository: TrainingRepository
    private var sessionID: UUID?
    private var startDate: Date?
    private var restTask: Task<Void, Never>?
    private var hasRestored = false

    init(workout: Workout, repository: TrainingRepository) {
        self.workout = workout
        self.repository = repository
        if !workout.exercises.isEmpty {
            loadSuggestedReps()
        }
    }

    var currentExercise: WorkoutExercise {
        workout.exercises[currentExerciseIndex]
    }

    var exerciseProgress: Double {
        Double(currentExerciseIndex + 1) / Double(workout.exercises.count)
    }

    var completedSetCount: Int {
        completedSets.filter {
            $0.exerciseID == currentExercise.exerciseID
        }.count
    }

    var currentSetNumber: Int {
        min(completedSetCount + 1, currentExercise.sets)
    }

    var isCurrentExerciseComplete: Bool {
        completedSetCount >= currentExercise.sets
    }

    var canMovePrevious: Bool {
        currentExerciseIndex > 0 && !isResting && !isSaving
    }

    var canMoveNext: Bool {
        currentExerciseIndex < workout.exercises.count - 1
            && !isResting && !isSaving
    }

    var formattedRestTime: String {
        String(
            format: "%d:%02d",
            restSecondsRemaining / 60,
            restSecondsRemaining % 60
        )
    }

    func restoreIfNeeded() async {
        guard !hasRestored else { return }
        hasRestored = true
        isLoading = true
        errorMessage = nil

        do {
            if !workout.exercises.isEmpty,
               let restored = try await repository.restoreSession(
                for: workout
            ) {
                apply(restored)
                phase = .active
                moveToFirstIncompleteExercise()
            }
            await loadPreviousValue()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        isLoading = false
    }

    func retryRestore() async {
        hasRestored = false
        await restoreIfNeeded()
    }

    func startWorkout() async {
        guard !isSaving else { return }
        guard !workout.exercises.isEmpty else {
            errorMessage = "This workout does not have any exercises yet."
            return
        }
        isSaving = true
        errorMessage = nil

        do {
            let session = try await repository.startSession(for: workout)
            apply(session)
            phase = .active
            moveToFirstIncompleteExercise()
            await AnalyticsService.shared.track(.workoutStarted)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        isSaving = false
    }

    func markSetComplete() async {
        guard !isSaving, !isCurrentExerciseComplete else { return }
        guard let sessionID else {
            errorMessage = "Start the workout before completing a set."
            return
        }
        guard let enteredWeight = Double(weight), enteredWeight >= 0,
              let enteredReps = Int(reps), enteredReps > 0 else {
            errorMessage = "Enter a valid weight and number of reps."
            return
        }

        isSaving = true
        errorMessage = nil
        let pendingSet = WorkoutSetLog(
            exerciseID: currentExercise.exerciseID,
            exerciseName: currentExercise.name,
            setNumber: currentSetNumber,
            weight: enteredWeight,
            reps: enteredReps,
            rpe: rpe,
            painLevel: painLevel,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let savedSet = try await repository.saveSet(
                pendingSet,
                sessionID: sessionID,
                prescription: currentExercise
            )
            completedSets.append(savedSet)
            await AnalyticsService.shared.track(.workoutSetCompleted)
            syncStatusMessage = await repository.hasPendingLogs()
                ? "Saved offline — sync pending"
                : "Synced"
            notes = ""
            if !isCurrentExerciseComplete {
                startRestTimer(seconds: currentExercise.restSeconds)
            } else if currentExerciseIndex < workout.exercises.count - 1 {
                moveToExercise(at: currentExerciseIndex + 1)
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        isSaving = false
    }

    func finishWorkout() async {
        guard !isSaving, let sessionID, let startDate else { return }
        isSaving = true
        errorMessage = nil
        skipRest()

        do {
            summary = try await repository.finishSession(
                id: sessionID,
                startedAt: startDate,
                sets: completedSets
            )
            syncStatusMessage = await repository.hasPendingLogs()
                ? "Workout saved offline — sync pending"
                : "Workout synced"
            phase = .summary
            await AnalyticsService.shared.track(.workoutCompleted)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        isSaving = false
    }

    func movePrevious() {
        guard canMovePrevious else { return }
        moveToExercise(at: currentExerciseIndex - 1)
    }

    func moveNext() {
        guard canMoveNext else { return }
        moveToExercise(at: currentExerciseIndex + 1)
    }

    func skipRest() {
        restTask?.cancel()
        restTask = nil
        isResting = false
        restSecondsRemaining = 0
    }

    private func apply(_ session: RestoredWorkoutSession) {
        sessionID = session.id
        startDate = session.startedAt
        completedSets = session.sets
    }

    private func moveToFirstIncompleteExercise() {
        if let index = workout.exercises.firstIndex(where: { exercise in
            completedSets.filter {
                $0.exerciseID == exercise.exerciseID
            }.count < exercise.sets
        }) {
            moveToExercise(at: index)
        } else if !workout.exercises.isEmpty {
            moveToExercise(at: workout.exercises.count - 1)
        }
    }

    private func moveToExercise(at index: Int) {
        currentExerciseIndex = index
        errorMessage = nil
        weight = ""
        notes = ""
        rpe = 7
        painLevel = 1
        loadSuggestedReps()
        Task { await loadPreviousValue() }
    }

    private func loadPreviousValue() async {
        do {
            previousWorkoutValue = try await repository.loadPreviousValue(
                exerciseID: currentExercise.exerciseID
            )
        } catch {
            previousWorkoutValue = nil
        }
    }

    private func startRestTimer(seconds: Int) {
        restTask?.cancel()
        restSecondsRemaining = seconds
        isResting = true
        restTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.restSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.restSecondsRemaining -= 1
            }
            guard !Task.isCancelled else { return }
            self.isResting = false
        }
    }

    private func loadSuggestedReps() {
        let digits = currentExercise.reps.prefix { $0.isNumber }
        reps = String(Int(digits) ?? 1)
    }

    private func friendlyMessage(for error: Error) -> String {
        if (error as NSError).domain == NSURLErrorDomain {
            return "You're offline. Your set wasn't saved. Try again."
        }
        return error.localizedDescription
    }

    deinit {
        restTask?.cancel()
    }
}
