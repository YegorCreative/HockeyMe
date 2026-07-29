import Combine
import Foundation

@MainActor
final class AthleteAssignmentViewModel: ObservableObject {
    @Published private(set) var athletes: [ProgramAthlete] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    let program: TrainingProgram
    private let repository: ProgramRepository

    init(program: TrainingProgram, repository: ProgramRepository) {
        self.program = program
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            athletes = try await repository.loadAssignableAthletes(
                programID: program.id
            )
        } catch {
            errorMessage = friendly(error)
        }
        isLoading = false
    }

    func toggle(_ athlete: ProgramAthlete) async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        do {
            if let assignmentID = athlete.assignmentID {
                try await repository.removeAssignment(id: assignmentID)
            } else {
                try await repository.assign(
                    athleteID: athlete.id,
                    to: program
                )
            }
            athletes = try await repository.loadAssignableAthletes(
                programID: program.id
            )
        } catch {
            errorMessage = friendly(error)
        }
        isSaving = false
    }

    private func friendly(_ error: Error) -> String {
        (error as NSError).domain == NSURLErrorDomain
            ? "You're offline. Check your connection and try again."
            : error.localizedDescription
    }
}
