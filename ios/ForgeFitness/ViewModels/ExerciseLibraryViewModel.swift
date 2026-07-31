import Combine
import Foundation

@MainActor
final class ExerciseLibraryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: HockeyExerciseCategory?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    let categories = HockeyExerciseCategory.allCases

    private let service: ExerciseService
    @Published private var allExercises: [Exercise] = []
    private var hasLoaded = false

    init(service: ExerciseService) {
        self.service = service
    }

    var exercises: [Exercise] {
        allExercises.filter { exercise in
            let matchesCategory = selectedCategory == nil
                || exercise.hockeyCategory == selectedCategory
            let matchesSearch = searchText.isEmpty
                || exercise.name.localizedStandardContains(searchText)
                || exercise.primaryMuscles.contains {
                    $0.rawValue.localizedStandardContains(searchText)
                }
            return matchesCategory && matchesSearch
        }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            allExercises = try await service.fetchExercises()
            hasLoaded = true
        } catch {
            guard !(error is CancellationError) else { return }
            errorMessage = AppErrorPresentation.make(for: error).combinedMessage
        }
    }

    func select(_ category: HockeyExerciseCategory?) {
        selectedCategory = category
    }
}
