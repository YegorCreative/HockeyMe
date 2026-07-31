import SwiftUI

struct WorkoutSummaryView: View {
    let workoutTitle: String
    let summary: WorkoutSessionSummary
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.success)
                        .accessibilityHidden(true)

                    Text("Workout Complete")
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text(workoutTitle)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: AppSpacing.md
                ) {
                    MetricCard(
                        title: "Total Volume",
                        value: "\(summary.totalVolume.formatted(.number.precision(.fractionLength(0)))) lb"
                    )
                    MetricCard(
                        title: "Total Sets",
                        value: String(summary.totalSets)
                    )
                    MetricCard(
                        title: "Total Reps",
                        value: String(summary.totalReps)
                    )
                    MetricCard(
                        title: "Duration",
                        value: formattedDuration
                    )
                }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Personal Records")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    if summary.personalRecords.isEmpty {
                        Text("Keep training—your next record is ahead.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        ForEach(summary.personalRecords, id: \.self) { record in
                            Label(record, systemImage: "trophy.fill")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                )

                PrimaryButton(title: "Done") {
                    onDone()
                }
                .accessibilityHint("Returns to the workouts list")
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var formattedDuration: String {
        let minutes = summary.durationSeconds / 60
        let seconds = summary.durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
