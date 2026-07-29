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
            ContentUnavailableView {
                Label(
                    "Workouts Unavailable",
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.retry() }
                }
            }
            .background(AppColors.background)
        } else if viewModel.workouts.isEmpty {
            ContentUnavailableView(
                "No Active Program",
                systemImage: "dumbbell",
                description: Text(
                    "Your coach has not assigned an active training program."
                )
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
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

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
                        WorkoutRow(
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

private struct WorkoutRow: View {
    let workout: Workout
    let isEmphasized: Bool

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(
                systemName: workout.status == .completed
                    ? "checkmark.circle.fill"
                    : "figure.strengthtraining.traditional"
            )
            .font(AppTypography.title)
            .foregroundStyle(
                workout.status == .completed
                    ? AppColors.success
                    : AppColors.primary
            )
            .frame(width: AppSpacing.xl)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(workout.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    Label(
                        "\(workout.estimatedDurationMinutes) min",
                        systemImage: "clock"
                    )
                    Text(
                        workout.scheduledDate.formatted(
                            date: .abbreviated,
                            time: .omitted
                        )
                    )
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.md)
        .background(
            isEmphasized
                ? AppColors.primary.opacity(0.1)
                : AppColors.surface
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay {
            if isEmphasized {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.primary, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(workout.title), \(workout.estimatedDurationMinutes) minutes, \(workout.scheduledDate.formatted(date: .abbreviated, time: .omitted))"
        )
    }
}
