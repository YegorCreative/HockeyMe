import SwiftUI

struct WorkoutListView: View {
    @StateObject private var viewModel: WorkoutViewModel
    private let repository: TrainingRepository
    private let exerciseService: ExerciseService?

    init(
        repository: TrainingRepository,
        exerciseService: ExerciseService?
    ) {
        self.repository = repository
        self.exerciseService = exerciseService
        _viewModel = StateObject(
            wrappedValue: WorkoutViewModel(repository: repository)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !viewModel.workouts.isEmpty {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                        workoutSection(
                            title: "Today's Workout",
                            workouts: viewModel.todaysWorkouts,
                            emphasis: true
                        )
                        workoutSection(
                            title: "Upcoming Workouts",
                            workouts: viewModel.upcomingWorkouts
                        )
                        workoutSection(
                            title: "Completed Workouts",
                            workouts: viewModel.completedWorkouts
                        )
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .background(AppColors.background)
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let exerciseService {
                        NavigationLink {
                            ExerciseLibraryView(service: exerciseService)
                        } label: {
                            Label(
                                "Exercise Library",
                                systemImage: "hockey.puck.fill"
                            )
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                stateOverlay
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        if viewModel.isLoading && viewModel.workouts.isEmpty {
            LoadingView()
                .background(AppColors.background)
        } else if let error = viewModel.errorMessage,
                  viewModel.workouts.isEmpty {
            ForgeErrorState(
                title: "Workouts Unavailable",
                message: error,
                retry: {
                    Task { await viewModel.retry() }
                }
            )
            .background(AppColors.background)
        } else if viewModel.workouts.isEmpty {
            ForgeEmptyState(
                title: "No Active Program",
                message: "Your coach has not assigned an active training program.",
                systemImage: "dumbbell",
            )
            .background(AppColors.background)
        }
    }

    private func workoutSection(
        title: String,
        workouts: [Workout],
        emphasis: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: title)

            if workouts.isEmpty {
                Text("No workouts")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(
                            workout: workout,
                            repository: repository
                        )
                    } label: {
                        WorkoutCard(
                            workout: workout,
                            isEmphasized: emphasis
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens workout details")
                }
            }
        }
    }
}
