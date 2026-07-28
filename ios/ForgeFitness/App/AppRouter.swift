import Combine

enum AppRoute {
    case authentication
    case athleteHome
    case coachHome
    case loading
}

final class AppRouter: ObservableObject {
    @Published var route: AppRoute = .authentication
}
