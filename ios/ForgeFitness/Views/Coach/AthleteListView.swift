import SwiftUI

struct AthleteListView: View {
    @ObservedObject var viewModel: CoachHomeViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.athletes) { athlete in
                NavigationLink {
                    AthleteDetailView(athlete: athlete)
                } label: {
                    athleteRow(athlete)
                }
                .listRowBackground(AppColors.background)
                .accessibilityHint("Opens athlete details")
            }
            .listStyle(.plain)
            .background(AppColors.background)
            .navigationTitle("Athletes")
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
                            "Athletes Unavailable",
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

    private func athleteRow(_ athlete: CoachAthlete) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(athlete.name)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        "\(athlete.team) • \(athlete.position) • \(athlete.graduationYear)"
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                recoveryBadge(score: athlete.recoveryScore)
            }

            HStack(spacing: AppSpacing.lg) {
                rowMetric(
                    title: "Last Workout",
                    value: athlete.lastWorkout
                )
                rowMetric(
                    title: "Compliance",
                    value: "\(athlete.compliance)%"
                )
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(athlete.name), \(athlete.team), \(athlete.position), graduation year \(athlete.graduationYear). Last workout \(athlete.lastWorkout). Compliance \(athlete.compliance) percent. Recovery score \(athlete.recoveryScore)."
        )
    }

    private func rowMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            Text(value)
                .font(AppTypography.body)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private func recoveryBadge(score: Int) -> some View {
        VStack(spacing: 0) {
            Text("\(score)")
                .font(AppTypography.headline)
                .fontWeight(.bold)

            Text("Recovery")
                .font(AppTypography.caption)
        }
        .foregroundStyle(score >= 80 ? AppColors.success : AppColors.warning)
        .accessibilityHidden(true)
    }
}
