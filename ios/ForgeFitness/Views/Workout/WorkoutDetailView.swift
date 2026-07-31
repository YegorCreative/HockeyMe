import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WorkoutSessionViewModel

    init(workout: Workout, repository: TrainingRepository) {
        _viewModel = StateObject(
            wrappedValue: WorkoutSessionViewModel(
                workout: workout,
                repository: repository
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .ready:
                workoutOverview
            case .active:
                WorkoutSessionView(viewModel: viewModel)
            case .summary:
                if let summary = viewModel.summary {
                    WorkoutSummaryView(
                        workoutTitle: viewModel.workout.title,
                        summary: summary,
                        onDone: dismiss.callAsFunction
                    )
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.phase == .active)
        .task {
            await viewModel.restoreIfNeeded()
        }
        .overlay {
            if viewModel.isLoading {
                LoadingView()
                    .background(AppColors.background)
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.phase {
        case .ready:
            viewModel.workout.title
        case .active:
            "Workout"
        case .summary:
            "Summary"
        }
    }

    private var workoutOverview: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(viewModel.workout.title)
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(viewModel.workout.description)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)

                    Label(
                        "\(viewModel.workout.estimatedDurationMinutes) min",
                        systemImage: "clock"
                    )
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.primary)
                }
                .accessibilityElement(children: .combine)

                SectionHeader(title: "Exercises")

                if viewModel.workout.exercises.isEmpty {
                    Text("No exercises have been added to this workout.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(
                        Array(viewModel.workout.exercises.enumerated()),
                        id: \.element.id
                    ) { index, exercise in
                    HStack(spacing: AppSpacing.md) {
                        Text("\(index + 1)")
                            .font(AppTypography.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(
                                width: AppSpacing.xl,
                                height: AppSpacing.xl
                            )
                            .background(AppColors.primary)
                            .clipShape(Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(exercise.name)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Text(
                                "\(exercise.sets) sets • \(exercise.reps) reps"
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                    )
                    .accessibilityElement(children: .combine)
                    }
                }

                PrimaryButton(
                    title: "Start Workout",
                    systemImage: "play.fill",
                    isLoading: viewModel.isSaving,
                    isDisabled: viewModel.workout.exercises.isEmpty
                ) {
                    Task {
                        await viewModel.startWorkout()
                    }
                }
                .accessibilityHint(
                    "Begins the exercise-by-exercise workout session"
                )

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.error)
                        .accessibilityLabel("Error: \(error)")

                    Button("Try Again") {
                        Task {
                            await viewModel.retryRestore()
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }
}
