import SwiftUI

struct AthleteAssignmentView: View {
    @StateObject private var viewModel: AthleteAssignmentViewModel

    init(program: TrainingProgram, repository: ProgramRepository) {
        _viewModel = StateObject(
            wrappedValue: AthleteAssignmentViewModel(
                program: program,
                repository: repository
            )
        )
    }

    var body: some View {
        List(viewModel.athletes) { athlete in
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(athlete.name)
                        .font(AppTypography.headline)
                    Text(
                        "\(athlete.team) • \(athlete.position) • \(athlete.graduationYear)"
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Button(athlete.isAssigned ? "Remove" : "Assign") {
                    Task { await viewModel.toggle(athlete) }
                }
                .buttonStyle(.bordered)
                .tint(
                    athlete.isAssigned
                        ? AppColors.error
                        : AppColors.primary
                )
                .disabled(viewModel.isSaving)
                .accessibilityLabel(
                    "\(athlete.isAssigned ? "Remove" : "Assign") \(athlete.name)"
                )
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.athletes.isEmpty {
                LoadingView().background(AppColors.background)
            } else if let error = viewModel.errorMessage,
                      viewModel.athletes.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Assignments Unavailable",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                }
            } else if viewModel.athletes.isEmpty {
                ContentUnavailableView(
                    "No Athletes",
                    systemImage: "person.3",
                    description: Text(
                        "Athletes appear here after completing onboarding."
                    )
                )
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .navigationTitle("Assignments")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
}
