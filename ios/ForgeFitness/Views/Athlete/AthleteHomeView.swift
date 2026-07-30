import SwiftUI

struct AthleteHomeView: View {
    @StateObject private var viewModel: AthleteHomeViewModel
    private let athleteService: AthleteService
    private let trainingRepository: TrainingRepository
    private let exerciseService: ExerciseService?
    private let testingRepository: TestingRepository?

    init(
        athleteService: AthleteService,
        trainingRepository: TrainingRepository,
        exerciseService: ExerciseService?,
        testingRepository: TestingRepository?
    ) {
        self.athleteService = athleteService
        self.trainingRepository = trainingRepository
        self.exerciseService = exerciseService
        self.testingRepository = testingRepository
        _viewModel = StateObject(
            wrappedValue: AthleteHomeViewModel(
                athleteService: athleteService
            )
        )
    }

    var body: some View {
        TabView {
            dashboard
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            WorkoutListView(
                repository: trainingRepository,
                exerciseService: exerciseService
            )
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell.fill")
                }

            Group {
                if let testingRepository {
                    TestingDashboardView(
                        role: .athlete,
                        repository: testingRepository,
                        athleteService: athleteService
                    )
                } else {
                    PlaceholderTabView(title: "Progress")
                }
            }
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            PlaceholderTabView(title: "Messages")
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }

            AthleteProfileView(athleteService: athleteService)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(AppColors.primary)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var dashboard: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    greeting
                    todaysWorkout
                    metricCards
                    quickStats
                    recentActivity
                    upcomingTesting
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.athlete == nil {
                    LoadingView()
                        .background(AppColors.background)
                } else if let error = viewModel.errorMessage,
                          viewModel.athlete == nil {
                    ContentUnavailableView {
                        Label(
                            "Profile Unavailable",
                            systemImage: "exclamationmark.triangle"
                        )
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    }
                    .background(AppColors.background)
                }
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(viewModel.greeting)
                .font(AppTypography.title)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textPrimary)

            Text("Ready to get better today?")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var todaysWorkout: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Today's Workout", systemImage: "bolt.fill")
                .font(AppTypography.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)

            Text(viewModel.todaysWorkout.title)
                .font(AppTypography.title)
                .fontWeight(.bold)

            Text(viewModel.todaysWorkout.detail)
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: AppSpacing.lg) {
                Label(
                    viewModel.todaysWorkout.duration,
                    systemImage: "clock"
                )
                Label(
                    viewModel.todaysWorkout.intensity,
                    systemImage: "flame.fill"
                )
            }
            .font(AppTypography.caption)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .accessibilityElement(children: .combine)
    }

    private var metricCards: some View {
        HStack(spacing: AppSpacing.md) {
            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("Recovery", systemImage: "heart.fill")
                        .foregroundStyle(AppColors.success)

                    Text("\(viewModel.recoveryScore)")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)

                    Text("Recovery Score")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Recovery score: \(viewModel.recoveryScore) out of 100"
            )

            DashboardCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("Streak", systemImage: "flame.fill")
                        .foregroundStyle(AppColors.warning)

                    Text("\(viewModel.workoutStreak)")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)

                    Text("Days in a Row")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Current workout streak: \(viewModel.workoutStreak) days"
            )
        }
        .font(AppTypography.caption)
    }

    private var quickStats: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Quick Stats")

            DashboardCard {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.quickStats) { stat in
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: stat.symbol)
                                .foregroundStyle(AppColors.secondary)
                                .accessibilityHidden(true)

                            Text(stat.value)
                                .font(AppTypography.headline)

                            Text(stat.title)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Recent Activity")

            DashboardCard {
                VStack(spacing: 0) {
                    ForEach(
                        Array(viewModel.recentActivities.enumerated()),
                        id: \.element.id
                    ) { index, activity in
                        activityRow(activity)

                        if index < viewModel.recentActivities.count - 1 {
                            Divider()
                                .padding(
                                    .leading,
                                    AppSpacing.xl + AppSpacing.md
                                )
                        }
                    }
                }
            }
        }
    }

    private var upcomingTesting: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Upcoming Testing")

            DashboardCard {
                VStack(spacing: 0) {
                    ForEach(
                        Array(viewModel.upcomingTests.enumerated()),
                        id: \.element.id
                    ) { index, test in
                        testingRow(test)

                        if index < viewModel.upcomingTests.count - 1 {
                            Divider()
                                .padding(
                                    .leading,
                                    AppSpacing.xl + AppSpacing.md
                                )
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func activityRow(_ activity: ActivitySummary) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: activity.symbol)
                .foregroundStyle(AppColors.primary)
                .frame(width: AppSpacing.xl)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(activity.title)
                    .font(AppTypography.body)
                    .fontWeight(.medium)

                Text(activity.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func testingRow(_ test: TestingSummary) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: test.symbol)
                .foregroundStyle(AppColors.secondary)
                .frame(width: AppSpacing.xl)
                .accessibilityHidden(true)

            Text(test.title)
                .font(AppTypography.body)
                .fontWeight(.medium)

            Spacer()

            Text(test.date)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: AppRadius.medium)
            )
    }
}

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        NavigationStack {
            Text(title)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
