import Combine
import Foundation

@MainActor
final class AthleteOnboardingViewModel: ObservableObject {
    static let stepCount = 5

    @Published var firstName = ""
    @Published var lastName = ""
    @Published var dateOfBirth = Calendar.current.date(
        byAdding: .year,
        value: -16,
        to: Date()
    ) ?? Date()
    @Published var height = ""
    @Published var weight = ""
    @Published var position = AthletePosition.center
    @Published var team = ""
    @Published var graduationYear = Calendar.current.component(
        .year,
        from: Date()
    )
    @Published var shoots = ShootingSide.left
    @Published var trainingGoals = ""
    @Published private(set) var currentStep = 0
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    let graduationYears: [Int]

    private let athleteService: AthleteService

    init(athleteService: AthleteService) {
        self.athleteService = athleteService
        let currentYear = Calendar.current.component(.year, from: Date())
        graduationYears = Array((currentYear - 2)...(currentYear + 10))
    }

    var progress: Double {
        Double(currentStep + 1) / Double(Self.stepCount)
    }

    var isFirstStep: Bool {
        currentStep == 0
    }

    var isLastStep: Bool {
        currentStep == Self.stepCount - 1
    }

    func goBack() {
        guard !isFirstStep else {
            return
        }

        errorMessage = nil
        currentStep -= 1
    }

    func goNext() {
        guard validateCurrentStep(), !isLastStep else {
            return
        }

        currentStep += 1
    }

    func save() async -> Bool {
        guard validateCurrentStep(),
              let heightInches = Double(height),
              let weightPounds = Double(weight) else {
            return false
        }

        isSaving = true
        errorMessage = nil

        do {
            let userID = try await athleteService.currentUserID()
            let athlete = Athlete(
                userID: userID,
                firstName: trimmed(firstName),
                lastName: trimmed(lastName),
                dateOfBirth: dateOfBirth,
                heightInches: heightInches,
                weightPounds: weightPounds,
                position: position,
                team: trimmed(team),
                graduationYear: graduationYear,
                shoots: shoots,
                trainingGoals: trimmed(trainingGoals)
            )

            try await athleteService.saveProfile(athlete)
            isSaving = false
            return true
        } catch {
            errorMessage = "We couldn't save your profile. Please check your connection and try again."
            isSaving = false
            return false
        }
    }

    private func validateCurrentStep() -> Bool {
        errorMessage = nil

        switch currentStep {
        case 0:
            guard !trimmed(firstName).isEmpty,
                  !trimmed(lastName).isEmpty,
                  dateOfBirth < Date() else {
                errorMessage = "Enter your name and a valid date of birth."
                return false
            }
        case 1:
            guard let height = Double(height),
                  (36...96).contains(height),
                  let weight = Double(weight),
                  (50...500).contains(weight) else {
                errorMessage = "Enter a height from 36–96 inches and a weight from 50–500 pounds."
                return false
            }
        case 2:
            guard !trimmed(team).isEmpty else {
                errorMessage = "Enter your current team."
                return false
            }
        case 3:
            guard graduationYears.contains(graduationYear) else {
                errorMessage = "Select a valid graduation year."
                return false
            }
        case 4:
            guard !trimmed(trainingGoals).isEmpty else {
                errorMessage = "Tell us at least one training goal."
                return false
            }
        default:
            return false
        }

        return true
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
