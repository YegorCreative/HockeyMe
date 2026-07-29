import SwiftUI

struct AthleteProfileView: View {
    @StateObject private var viewModel: AthleteProfileViewModel

    init(athleteService: AthleteService) {
        _viewModel = StateObject(
            wrappedValue: AthleteProfileViewModel(
                athleteService: athleteService
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.athlete == nil {
                    LoadingView()
                } else if let error = viewModel.errorMessage,
                          viewModel.athlete == nil {
                    ContentUnavailableView {
                        Label("Profile Unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    }
                } else if viewModel.athlete != nil {
                    profileForm
                } else {
                    ContentUnavailableView(
                        "No Athlete Profile",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Complete onboarding to create your profile.")
                    )
                }
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var profileForm: some View {
        Form {
            Section("Personal") {
                TextField("First Name", text: $viewModel.firstName)
                    .textContentType(.givenName)
                TextField("Last Name", text: $viewModel.lastName)
                    .textContentType(.familyName)
            }

            Section("Training Profile") {
                TextField("Height (inches)", text: $viewModel.height)
                    .keyboardType(.decimalPad)
                TextField("Weight (pounds)", text: $viewModel.weight)
                    .keyboardType(.decimalPad)
                TextField("Team", text: $viewModel.team)
                    .textContentType(.organizationName)
                TextField(
                    "Training Goals",
                    text: $viewModel.trainingGoals,
                    axis: .vertical
                )
                .lineLimit(3...6)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(AppColors.error)
                    .accessibilityLabel("Error: \(error)")
            }

            if let success = viewModel.successMessage {
                Text(success)
                    .foregroundStyle(AppColors.success)
                    .accessibilityLabel(success)
            }

            Button {
                Task {
                    await viewModel.save()
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Saving profile")
                } else {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isSaving)
        }
        .font(AppTypography.body)
        .refreshable {
            await viewModel.refresh()
        }
    }
}
