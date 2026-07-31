import Combine
import Foundation

@MainActor
final class AthleteProfileViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var height = ""
    @Published var weight = ""
    @Published var team = ""
    @Published var trainingGoals = ""
    @Published private(set) var athlete: Athlete?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?

    private let athleteService: AthleteService
    private var hasLoaded = false

    init(athleteService: AthleteService) {
        self.athleteService = athleteService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await load()
    }

    func refresh() async {
        await load()
    }

    func retry() async {
        await load()
    }

    func save() async {
        guard let athlete,
              !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let heightValue = Double(height),
              (36...96).contains(heightValue),
              let weightValue = Double(weight),
              (50...500).contains(weightValue) else {
            errorMessage = "Enter a valid name, height, and weight."
            return
        }

        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        successMessage = nil

        let updatedAthlete = Athlete(
            userID: athlete.userID,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: athlete.dateOfBirth,
            heightInches: heightValue,
            weightPounds: weightValue,
            position: athlete.position,
            team: team.trimmingCharacters(in: .whitespacesAndNewlines),
            graduationYear: athlete.graduationYear,
            shoots: athlete.shoots,
            trainingGoals: trainingGoals.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )

        do {
            try await athleteService.updateProfile(updatedAthlete)
            self.athlete = updatedAthlete
            successMessage = "Profile updated."
        } catch {
            guard !(error is CancellationError) else { return }
            errorMessage = AppErrorPresentation.make(for: error).combinedMessage
        }
    }

    private func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let athlete = try await athleteService.loadCurrentProfile()
            self.athlete = athlete
            apply(athlete)
            hasLoaded = true
        } catch {
            guard !(error is CancellationError) else { return }
            errorMessage = AppErrorPresentation.make(for: error).combinedMessage
        }
    }

    private func apply(_ athlete: Athlete) {
        firstName = athlete.firstName
        lastName = athlete.lastName
        height = String(Int(athlete.heightInches))
        weight = String(Int(athlete.weightPounds))
        team = athlete.team
        trainingGoals = athlete.trainingGoals
    }
}
