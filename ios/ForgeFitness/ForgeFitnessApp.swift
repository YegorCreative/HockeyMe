// xcode: set sdk=iOS

import SwiftUI

@main
struct ForgeFitnessApp: App {
    @StateObject private var router: AppRouter

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: nil,
                    athleteService: nil,
                    trainingRepository: nil,
                    programRepository: nil,
                    exerciseService: nil,
                    testingRepository: nil
                )
            )
            return
        }

        do {
            let manager = try SupabaseManager()
            let authService = AuthService(client: manager.client)
            let athleteService = AthleteService(client: manager.client)
            let trainingRepository = TrainingRepository(client: manager.client)
            let programRepository = ProgramRepository(client: manager.client)
            let exerciseService = ExerciseService(client: manager.client)
            let testingRepository = TestingRepository(client: manager.client)
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: authService,
                    athleteService: athleteService,
                    trainingRepository: trainingRepository,
                    programRepository: programRepository,
                    exerciseService: exerciseService,
                    testingRepository: testingRepository
                )
            )
        } catch {
            SupabaseDebugLogger.logConfigurationError(error)
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: nil,
                    athleteService: nil,
                    trainingRepository: nil,
                    programRepository: nil,
                    exerciseService: nil,
                    testingRepository: nil,
                    startupErrorMessage: "Forge Fitness has an invalid Supabase configuration. Please contact support."
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(router: router)
        }
    }
}

private struct AppRootView: View {
    @ObservedObject var router: AppRouter
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            routedContent
                .opacity(isShowingSplash ? 0 : 1)
                .accessibilityHidden(isShowingSplash)

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            await router.start()
        }
        .task {
            await hideSplashAfterDelay()
        }
    }

    @ViewBuilder
    private var routedContent: some View {
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
            if let athleteService = router.athleteService,
               let trainingRepository = router.trainingRepository {
                AthleteHomeView(
                    athleteService: athleteService,
                    trainingRepository: trainingRepository,
                    exerciseService: router.exerciseService,
                    testingRepository: router.testingRepository
                )
            }
        case .coachHome:
            if let athleteService = router.athleteService,
               let programRepository = router.programRepository {
                CoachHomeView(
                    athleteService: athleteService,
                    programRepository: programRepository,
                    testingRepository: router.testingRepository
                )
            }
        case .loading:
            LoadingView()
        }
    }

    private func hideSplashAfterDelay() async {
        guard isShowingSplash else {
            return
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        guard !Task.isCancelled else {
            return
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            isShowingSplash = false
        }
    }
}
