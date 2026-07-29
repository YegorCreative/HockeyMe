import Combine
import Foundation

@MainActor
final class ProgramListViewModel: ObservableObject {
    @Published private(set) var programs: [TrainingProgram] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    let repository: ProgramRepository
    private var hasLoaded = false

    init(repository: ProgramRepository) {
        self.repository = repository
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
            programs = try await repository.loadPrograms()
            hasLoaded = true
        } catch {
            errorMessage = friendly(error)
        }
        isLoading = false
    }

    func createProgram() async -> UUID? {
        await perform {
            let program = try await repository.createProgram()
            programs.insert(program, at: 0)
            return program.id
        }
    }

    func duplicate(_ program: TrainingProgram) async {
        _ = await perform {
            _ = try await repository.duplicateProgram(program)
            programs = try await repository.loadPrograms()
            return true
        }
    }

    func archive(_ program: TrainingProgram) async {
        _ = await perform {
            try await repository.setStatus(.archived, for: program)
            programs = try await repository.loadPrograms()
            return true
        }
    }

    private func perform<T>(
        _ operation: () async throws -> T
    ) async -> T? {
        errorMessage = nil
        do {
            return try await operation()
        } catch {
            errorMessage = friendly(error)
            return nil
        }
    }

    private func friendly(_ error: Error) -> String {
        (error as NSError).domain == NSURLErrorDomain
            ? "You're offline. Check your connection and try again."
            : error.localizedDescription
    }
}
