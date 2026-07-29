import SwiftUI

struct WorkoutSessionView: View {
    @ObservedObject var viewModel: WorkoutSessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                exerciseProgress
                exerciseHeader
                previousWorkout
                setProgress

                if viewModel.isResting {
                    restTimer
                } else if viewModel.isCurrentExerciseComplete {
                    completedExercise
                } else {
                    setEntry
                }

                exerciseNavigation

                Button("Finish Workout") {
                    Task {
                        await viewModel.finishWorkout()
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppColors.error)
                .frame(maxWidth: .infinity)
                .disabled(
                    viewModel.completedSets.isEmpty || viewModel.isSaving
                )
                .accessibilityHint(
                    "Ends the session and displays your workout summary"
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var exerciseProgress: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(
                    "Exercise \(viewModel.currentExerciseIndex + 1) of \(viewModel.workout.exercises.count)"
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Text(
                    "\(Int(viewModel.exerciseProgress * 100))%"
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            ProgressView(value: viewModel.exerciseProgress)
                .tint(AppColors.primary)
                .accessibilityLabel("Workout exercise progress")
                .accessibilityValue(
                    "\(viewModel.currentExerciseIndex + 1) of \(viewModel.workout.exercises.count)"
                )
        }
    }

    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(viewModel.currentExercise.name)
                .font(AppTypography.title)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.currentExercise.coachNotes)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var previousWorkout: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Previous Workout", systemImage: "clock.arrow.circlepath")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.secondary)

            Group {
                if let previous = viewModel.previousWorkoutValue {
                    Text(
                        "\(previous.weight.formatted()) lb • \(previous.reps) reps • RPE \(previous.rpe)"
                    )
                } else {
                    Text("No previous completed sets")
                }
            }
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
    }

    private var setProgress: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(
                "Set \(viewModel.currentSetNumber) of \(viewModel.currentExercise.sets)"
            )
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(1...viewModel.currentExercise.sets, id: \.self) { set in
                    Image(
                        systemName: set <= viewModel.completedSetCount
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .foregroundStyle(
                        set <= viewModel.completedSetCount
                            ? AppColors.success
                            : AppColors.border
                    )
                    .accessibilityLabel(
                        "Set \(set), \(set <= viewModel.completedSetCount ? "complete" : "not complete")"
                    )
                }
            }
        }
    }

    private var restTimer: some View {
        VStack(spacing: AppSpacing.md) {
            Label("Rest Timer", systemImage: "timer")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.secondary)

            Text(viewModel.formattedRestTime)
                .font(AppTypography.largeTitle)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityLabel(
                    "\(viewModel.restSecondsRemaining) seconds remaining"
                )

            Button("Skip Rest") {
                viewModel.skipRest()
            }
            .buttonStyle(.bordered)
            .tint(AppColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }

    private var completedExercise: some View {
        Label("All sets complete", systemImage: "checkmark.circle.fill")
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.success)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    private var setEntry: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                inputField(
                    title: "Weight (lb)",
                    text: $viewModel.weight,
                    keyboardType: .decimalPad
                )

                inputField(
                    title: "Reps",
                    text: $viewModel.reps,
                    keyboardType: .numberPad
                )
            }

            Stepper("RPE: \(viewModel.rpe)", value: $viewModel.rpe, in: 1...10)
                .accessibilityValue("\(viewModel.rpe) out of 10")

            Stepper(
                "Pain Level: \(viewModel.painLevel)",
                value: $viewModel.painLevel,
                in: 1...10
            )
            .accessibilityValue("\(viewModel.painLevel) out of 10")

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Notes")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                TextEditor(text: $viewModel.notes)
                    .frame(minHeight: 88)
                    .padding(AppSpacing.sm)
                    .background(AppColors.background)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .stroke(AppColors.border)
                    }
                    .accessibilityLabel("Set notes")
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.error)
                    .accessibilityLabel("Error: \(errorMessage)")
            }

            Button("Mark Set Complete") {
                Task {
                    await viewModel.markSetComplete()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isSaving)
            .accessibilityHint(
                "Saves this set and starts the rest timer"
            )
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    private var exerciseNavigation: some View {
        HStack {
            Button {
                viewModel.movePrevious()
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(!viewModel.canMovePrevious)

            Spacer()

            Button {
                viewModel.moveNext()
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(!viewModel.canMoveNext)
        }
        .buttonStyle(.bordered)
        .tint(AppColors.primary)
    }

    private func inputField(
        title: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            TextField(title, text: text)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
    }
}
