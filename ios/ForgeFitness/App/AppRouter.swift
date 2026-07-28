import Combine

enum AppRoute {
    case authentication
    case athleteHome
    case coachHome
    case loading
}

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var route: AppRoute = .loading

    let authService: AuthService?
    let startupErrorMessage: String?

    private var isStarted = false
    private var authenticationTask: Task<Void, Never>?

    init(
        authService: AuthService?,
        startupErrorMessage: String? = nil
    ) {
        self.authService = authService
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

        route = await authService.restoreSession()
            ? .athleteHome
            : .authentication

        authenticationTask = Task { [weak self] in
            for await isAuthenticated in authService.authenticationChanges {
                guard !Task.isCancelled else {
                    return
                }

                self?.route = isAuthenticated
                    ? .athleteHome
                    : .authentication
            }
        }
    }

    deinit {
        authenticationTask?.cancel()
    }
}
