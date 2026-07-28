// xcode: set sdk=iOS

import SwiftUI

@main
struct ForgeFitnessApp: App {
    @StateObject private var router: AppRouter

    init() {
        do {
            let manager = try SupabaseManager()
            let authService = AuthService(client: manager.client)
            let athleteService = AthleteService(client: manager.client)
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: authService,
                    athleteService: athleteService
                )
            )
        } catch {
            SupabaseDebugLogger.logConfigurationError(error)
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: nil,
                    athleteService: nil,
                    startupErrorMessage: "Forge Fitness has an invalid Supabase configuration. Please contact support."
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
                case .athleteOnboarding:
                    if let athleteService = router.athleteService {
                        AthleteOnboardingView(
                            athleteService: athleteService,
                            onCompletion: {
                                router.completeAthleteOnboarding()
                            }
                        )
                    } else {
                        AuthenticationView(
                            authService: nil,
                            initialErrorMessage: router.startupErrorMessage
                        )
                    }
                case .athleteHome:
                    AthleteHomeView()
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
