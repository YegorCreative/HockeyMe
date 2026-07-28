import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                summary

                Text("Exercises")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(
                    Array(workout.exercises.enumerated()),
                    id: \.element.id
                ) { index, exercise in
                    ExerciseCard(
                        exercise: exercise,
                        number: index + 1
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(workout.title)
                .font(AppTypography.title)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textPrimary)

            Text(workout.description)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)

            Label(
                "Estimated duration: \(workout.estimatedDurationMinutes) minutes",
                systemImage: "clock"
            )
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.primary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExerciseCard: View {
    let exercise: Exercise
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number)")
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

                Text(exercise.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            HStack(spacing: AppSpacing.lg) {
                metric(title: "Sets", value: String(exercise.sets))
                metric(title: "Reps", value: exercise.reps)
                metric(
                    title: "Rest",
                    value: "\(exercise.restSeconds) sec"
                )
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("Coach Notes", systemImage: "quote.bubble")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.secondary)

                Text(exercise.coachNotes)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(exercise.name). \(exercise.sets) sets. \(exercise.reps) reps. \(exercise.restSeconds) seconds rest. Coach notes: \(exercise.coachNotes)"
        )
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            Text(value)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
