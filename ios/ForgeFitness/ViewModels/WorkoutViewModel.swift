import Combine
import Foundation

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published private(set) var workouts: [Workout] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let repository: TrainingRepository
    private var hasLoaded = false

    init(repository: TrainingRepository) {
        self.repository = repository
    }

    var todaysWorkouts: [Workout] {
        workouts.filter {
            $0.status == .scheduled
                && Calendar.current.isDateInToday($0.scheduledDate)
        }
    }

    var upcomingWorkouts: [Workout] {
        workouts.filter {
            $0.status == .scheduled
                && !Calendar.current.isDateInToday($0.scheduledDate)
        }
    }

    var completedWorkouts: [Workout] {
        workouts.filter { $0.status == .completed }
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

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            workouts = try await repository
                .loadActiveTrainingPlan()
                .workouts
            hasLoaded = true
        } catch TrainingRepositoryError.activeAssignmentMissing {
            workouts = []
            hasLoaded = true
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }

        isLoading = false
    }

    private static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "You're offline. Check your connection and try again."
        }
        return error.localizedDescription
    }
}
