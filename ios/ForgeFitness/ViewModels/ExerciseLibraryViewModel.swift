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
    private var allExercises: [Exercise] = []
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
        errorMessage = nil
        do {
            allExercises = try await service.fetchExercises()
            hasLoaded = true
            objectWillChange.send()
        } catch {
            errorMessage = (error as NSError).domain == NSURLErrorDomain
                ? "You're offline. Check your connection and try again."
                : error.localizedDescription
        }
        isLoading = false
    }

    func select(_ category: HockeyExerciseCategory?) {
        selectedCategory = category
    }
}
