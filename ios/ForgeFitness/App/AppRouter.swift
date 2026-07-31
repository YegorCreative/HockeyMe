import Combine

enum AppRoute: Equatable {
    case authentication
    case athleteOnboarding
    case athleteHome
    case coachHome
    case parentHome
    case loading
}

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var route: AppRoute = .loading

    let authService: AuthService?
    let athleteService: AthleteService?
    let trainingRepository: TrainingRepository?
    let programRepository: ProgramRepository?
    let exerciseService: ExerciseService?
    let testingRepository: TestingRepository?
    let organizationRepository: OrganizationRepository?
    let startupErrorMessage: String?

    private var isStarted = false
    private var authenticationTask: Task<Void, Never>?

    init(
        authService: AuthService?,
        athleteService: AthleteService?,
        trainingRepository: TrainingRepository?,
        programRepository: ProgramRepository?,
        exerciseService: ExerciseService?,
        testingRepository: TestingRepository? = nil,
        organizationRepository: OrganizationRepository? = nil,
        startupErrorMessage: String? = nil
    ) {
        self.authService = authService
        self.athleteService = athleteService
        self.trainingRepository = trainingRepository
        self.programRepository = programRepository
        self.exerciseService = exerciseService
        self.testingRepository = testingRepository
        self.organizationRepository = organizationRepository
        self.startupErrorMessage = startupErrorMessage
    }

    func start() async {
        guard !isStarted else {
            return
        }

        isStarted = true

        guard let authService else {
            route = .authentication
            return
        }

        if await authService.restoreSession() {
            await routeAuthenticatedUser()
        } else {
            route = .authentication
        }

        authenticationTask = Task { [weak self] in
            for await isAuthenticated in authService.authenticationChanges {
                guard !Task.isCancelled else {
                    return
                }

                guard let self else {
                    return
                }

                if isAuthenticated {
                    if route == .authentication || route == .loading {
                        await routeAuthenticatedUser()
                    }
                } else {
                    route = .authentication
                }
            }
        }
    }

    func completeAthleteOnboarding() {
        route = .athleteHome
    }

    private func routeAuthenticatedUser() async {
        if let context = try? await organizationRepository?.loadContext() {
            if context.roles.contains(where: \.isStaff) {
                route = .coachHome
                return
            }
            if context.roles.contains(.parent)
                && !context.roles.contains(.athlete) {
                route = .parentHome
                return
            }
        }

        if await programRepository?.isCurrentUserCoach() == true {
            route = .coachHome
            return
        }

        guard let athleteService else {
            route = .authentication
            return
        }

        route = .loading

        do {
            route = try await athleteService.hasProfile()
                ? .athleteHome
                : .athleteOnboarding
        } catch {
            route = .athleteOnboarding
        }
    }

    deinit {
        authenticationTask?.cancel()
    }
}
