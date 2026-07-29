import SwiftUI

struct AthleteDetailView: View {
    let athlete: CoachAthlete

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                profile
                recentWorkouts
                metricSection(
                    title: "Performance Summary",
                    metrics: athlete.performance,
                    symbol: "chart.line.uptrend.xyaxis"
                )
                metricSection(
                    title: "Recovery Summary",
                    metrics: athlete.recovery,
                    symbol: "heart.fill"
                )
                textSection(
                    title: "Coach Notes",
                    text: athlete.coachNotes,
                    symbol: "note.text"
                )
                textSection(
                    title: "Assigned Training Program",
                    text: athlete.assignedProgram,
                    symbol: "list.clipboard.fill"
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
        .navigationTitle(athlete.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(athlete.name)
                        .font(AppTypography.title)
                        .fontWeight(.bold)

                    Text(
                        "\(athlete.team) • \(athlete.position) • \(athlete.graduationYear)"
                    )
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
                }
            }

            Divider()

            HStack {
                profileMetric("Age", "\(athlete.profile.age)")
                profileMetric("Height", athlete.profile.height)
                profileMetric("Weight", athlete.profile.weight)
                profileMetric("Shoots", athlete.profile.shoots)
            }
        }
        .foregroundStyle(AppColors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
    }

    private var recentWorkouts: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Recent Workouts")

            CoachCard {
                if athlete.recentWorkouts.isEmpty {
                    Text("No workout history available.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    VStack(spacing: 0) {
                    ForEach(
                        Array(athlete.recentWorkouts.enumerated()),
                        id: \.element.id
                    ) { index, workout in
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(workout.title)
                                    .font(AppTypography.headline)

                                Text(workout.date)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            Text(workout.status)
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    workout.status == "Completed"
                                        ? AppColors.success
                                        : AppColors.error
                                )
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .accessibilityElement(children: .combine)

                        if index < athlete.recentWorkouts.count - 1 {
                            Divider()
                        }
                    }
                    }
                }
            }
        }
    }

    private func metricSection(
        title: String,
        metrics: [CoachMetric],
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle(title)

            CoachCard {
                if metrics.isEmpty {
                    Text("No data available yet.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    VStack(spacing: AppSpacing.md) {
                    ForEach(metrics) { metric in
                        HStack {
                            Image(systemName: symbol)
                                .foregroundStyle(AppColors.secondary)
                                .frame(width: AppSpacing.xl)
                                .accessibilityHidden(true)

                            Text(metric.title)
                                .font(AppTypography.body)

                            Spacer()

                            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                                Text(metric.value)
                                    .font(AppTypography.headline)

                                Text(metric.trend)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.success)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    }
                }
            }
        }
    }

    private func textSection(
        title: String,
        text: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle(title)

            CoachCard {
                Label {
                    Text(text)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(AppColors.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func profileMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(AppTypography.headline)

            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}
