import Combine
import Foundation

@MainActor
final class CoachHomeViewModel: ObservableObject {
    @Published private(set) var athletes: [CoachAthlete] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let athleteService: AthleteService
    private var hasLoaded = false

    init(athleteService: AthleteService) {
        self.athleteService = athleteService
    }

    var totalAthletes: Int { athletes.count }
    var activeToday: Int { 0 }
    var workoutsDueToday: Int { 0 }
    var athleteCompliance: Int { 0 }
    var recentActivity: [CoachActivity] { [] }
    var upcomingTesting: [CoachTestingEvent] { [] }

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

    private func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let profiles = try await athleteService.loadCoachAthletes()
            athletes = profiles.map(Self.makeCoachAthlete)
            hasLoaded = true
        } catch {
            guard !(error is CancellationError) else { return }
            errorMessage = Self.message(for: error)
        }
    }

    private static func makeCoachAthlete(
        from athlete: Athlete
    ) -> CoachAthlete {
        CoachAthlete(
            id: athlete.id,
            name: "\(athlete.firstName) \(athlete.lastName)",
            team: athlete.team,
            position: athlete.position.rawValue,
            graduationYear: athlete.graduationYear,
            lastWorkout: "Not available",
            compliance: 0,
            recoveryScore: 0,
            profile: CoachAthleteProfile(
                age: Calendar.current.dateComponents(
                    [.year],
                    from: athlete.dateOfBirth,
                    to: Date()
                ).year ?? 0,
                height: "\(Int(athlete.heightInches)) in",
                weight: "\(Int(athlete.weightPounds)) lb",
                shoots: athlete.shoots.rawValue
            ),
            recentWorkouts: [],
            performance: [],
            recovery: [],
            coachNotes: "No coach notes yet.",
            assignedProgram: "No training program assigned."
        )
    }

    private static func message(for error: Error) -> String {
        AppErrorPresentation.make(for: error).combinedMessage
    }
}

struct CoachActivity: Identifiable {
    let athleteName: String
    let detail: String
    let time: String
    let symbol: String

    var id: String { athleteName + detail }
}

struct CoachTestingEvent: Identifiable {
    let title: String
    let group: String
    let date: String

    var id: String { title + date }
}
