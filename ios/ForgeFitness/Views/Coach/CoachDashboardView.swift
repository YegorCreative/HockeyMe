import SwiftUI

struct CoachDashboardView: View {
    @ObservedObject var viewModel: CoachHomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Team Overview")
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    metrics
                    recentActivity
                    upcomingTesting
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background)
            .navigationTitle("Coach Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.athletes.isEmpty {
                    LoadingView()
                        .background(AppColors.background)
                } else if let error = viewModel.errorMessage,
                          viewModel.athletes.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "Dashboard Unavailable",
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
                } else if viewModel.athletes.isEmpty {
                    ContentUnavailableView(
                        "No Athletes",
                        systemImage: "person.3",
                        description: Text(
                            "Athletes will appear after they complete onboarding."
                        )
                    )
                    .background(AppColors.background)
                }
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppSpacing.md),
                GridItem(.flexible())
            ],
            spacing: AppSpacing.md
        ) {
            metricCard(
                title: "Total Athletes",
                value: "\(viewModel.totalAthletes)",
                symbol: "person.3.fill",
                color: AppColors.primary
            )
            metricCard(
                title: "Active Today",
                value: "\(viewModel.activeToday)",
                symbol: "bolt.fill",
                color: AppColors.success
            )
            metricCard(
                title: "Workouts Due",
                value: "\(viewModel.workoutsDueToday)",
                symbol: "calendar.badge.clock",
                color: AppColors.warning
            )
            metricCard(
                title: "Compliance",
                value: "\(viewModel.athleteCompliance)%",
                symbol: "chart.bar.fill",
                color: AppColors.secondary
            )
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Recent Activity")

            CoachCard {
                if viewModel.recentActivity.isEmpty {
                    Text("No recent athlete activity.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    VStack(spacing: 0) {
                    ForEach(
                        Array(viewModel.recentActivity.enumerated()),
                        id: \.element.id
                    ) { index, activity in
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: activity.symbol)
                                .foregroundStyle(AppColors.primary)
                                .frame(width: AppSpacing.xl)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(activity.athleteName)
                                    .font(AppTypography.headline)

                                Text(activity.detail)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textSecondary)

                                Text(activity.time)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .accessibilityElement(children: .combine)

                        if index < viewModel.recentActivity.count - 1 {
                            Divider()
                        }
                    }
                    }
                }
            }
        }
    }

    private var upcomingTesting: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Upcoming Testing")

            CoachCard {
                if viewModel.upcomingTesting.isEmpty {
                    Text("No testing sessions scheduled.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    VStack(spacing: 0) {
                    ForEach(
                        Array(viewModel.upcomingTesting.enumerated()),
                        id: \.element.id
                    ) { index, event in
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "stopwatch.fill")
                                .foregroundStyle(AppColors.secondary)
                                .frame(width: AppSpacing.xl)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(event.title)
                                    .font(AppTypography.headline)

                                Text(event.group)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            Text(event.date)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .accessibilityElement(children: .combine)

                        if index < viewModel.upcomingTesting.count - 1 {
                            Divider()
                        }
                    }
                    }
                }
            }
        }
    }

    private func metricCard(
        title: String,
        value: String,
        symbol: String,
        color: Color
    ) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)

                Text(value)
                    .font(AppTypography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)

                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct CoachCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}
