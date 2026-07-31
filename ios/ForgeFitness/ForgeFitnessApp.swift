// xcode: set sdk=iOS

import SwiftUI

@main
struct ForgeFitnessApp: App {
    @StateObject private var router: AppRouter

    init() {
        DiagnosticsService.shared.start()
        LoggingService.shared.log(
            "application_launched",
            category: .application,
            metadata: LogMetadata([
                "environment": AppEnvironment.build.rawValue
            ])
        )
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: nil,
                    athleteService: nil,
                    trainingRepository: nil,
                    programRepository: nil,
                    exerciseService: nil,
                    testingRepository: nil,
                    organizationRepository: nil
                )
            )
            return
        }

        do {
            let manager = try SupabaseManager()
            let featureFlags = FeatureFlagService(client: manager.client)
            Task {
                do {
                    try await featureFlags.refresh()
                } catch {
                    LoggingService.shared.log(
                        "feature_flags_refresh_failed",
                        category: .errors,
                        level: .warning,
                        metadata: LogMetadata([
                            "error_type":
                                String(describing: type(of: error))
                        ])
                    )
                }
            }
            let authService = AuthService(client: manager.client)
            let athleteService = AthleteService(client: manager.client)
            let trainingRepository = TrainingRepository(client: manager.client)
            let programRepository = ProgramRepository(client: manager.client)
            let exerciseService = ExerciseService(client: manager.client)
            let testingRepository = TestingRepository(client: manager.client)
            let organizationRepository = OrganizationRepository(
                client: manager.client
            )
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: authService,
                    athleteService: athleteService,
                    trainingRepository: trainingRepository,
                    programRepository: programRepository,
                    exerciseService: exerciseService,
                    testingRepository: testingRepository,
                    organizationRepository: organizationRepository
                )
            )
        } catch SupabaseConfigurationError.fileNotFound {
            SupabaseDebugLogger.logConfigurationError(
                SupabaseConfigurationError.fileNotFound
            )
#if DEBUG
            _router = StateObject(
                wrappedValue: AppRouter(
                    developerStore: DeveloperModeStore()
                )
            )
#else
            _router = StateObject(
                wrappedValue: AppRouter(
                    authService: nil,
                    athleteService: nil,
                    trainingRepository: nil,
                    programRepository: nil,
                    exerciseService: nil,
                    startupErrorMessage: "Forge Fitness has an invalid Supabase configuration. Please contact support."
                )
            )
#endif
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
                    organizationRepository: nil,
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
#if DEBUG
        case .developerMode:
            if let developerStore = router.developerStore {
                DeveloperModeView(store: developerStore)
            }
#endif
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
                    testingRepository: router.testingRepository,
                    organizationRepository: router.organizationRepository
                )
            }
        case .coachHome:
            if let athleteService = router.athleteService,
               let programRepository = router.programRepository {
                CoachHomeView(
                    athleteService: athleteService,
                    programRepository: programRepository,
                    testingRepository: router.testingRepository,
                    organizationRepository: router.organizationRepository
                )
            }
        case .parentHome:
            if let organizationRepository = router.organizationRepository,
               let athleteService = router.athleteService {
                ParentHomeView(
                    organizationRepository: organizationRepository,
                    testingRepository: router.testingRepository,
                    athleteService: athleteService
                )
            }
        case .loading:
            LoadingView()
        case let .routingError(message):
            ForgeErrorState(
                title: "Account Unavailable",
                message: message,
                retry: {
                    Task { await router.retryRouting() }
                }
            )
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

        withAnimation(AppMotion.standardAnimation) {
            isShowingSplash = false
        }
    }
}
