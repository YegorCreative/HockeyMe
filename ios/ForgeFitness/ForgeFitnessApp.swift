// xcode: set sdk=iOS

import SwiftUI

@main
struct ForgeFitnessApp: App {
    @StateObject private var router: AppRouter

    init() {
        do {
            let manager = try SupabaseManager()
            let authService = AuthService(client: manager.client)
            _router = StateObject(
                wrappedValue: AppRouter(authService: authService)
            )
        } catch {
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: nil,
                    startupErrorMessage: "Forge Fitness could not connect to its authentication service. Please check the app configuration."
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.route {
                case .authentication:
                    AuthenticationView(
                        authService: router.authService,
                        initialErrorMessage: router.startupErrorMessage
                    )
                case .athleteHome:
                    if let authService = router.authService {
                        AthleteHomeView(authService: authService)
                    } else {
                        AuthenticationView(
                            authService: nil,
                            initialErrorMessage: router.startupErrorMessage
                        )
                    }
                case .coachHome:
                    CoachHomeView()
                case .loading:
                    LoadingView()
                }
            }
            .task {
                await router.start()
            }
        }
    }
}
