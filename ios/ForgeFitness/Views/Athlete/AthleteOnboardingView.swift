import SwiftUI

struct AthleteOnboardingView: View {
    @StateObject private var viewModel: AthleteOnboardingViewModel

    private let onCompletion: @MainActor () -> Void

    init(
        athleteService: AthleteService,
        onCompletion: @escaping @MainActor () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AthleteOnboardingViewModel(
                athleteService: athleteService
            )
        )
        self.onCompletion = onCompletion
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            header

            ScrollView {
                stepContent
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
            }

            navigation
        }
        .padding(.top, AppSpacing.lg)
        .background(AppColors.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Athlete Profile")
                    .font(AppTypography.title)
                    .fontWeight(.bold)

                Spacer()

                Text("\(viewModel.currentStep + 1) of \(AthleteOnboardingViewModel.stepCount)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ProgressView(value: viewModel.progress)
                .tint(AppColors.primary)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue(
                    "Step \(viewModel.currentStep + 1) of \(AthleteOnboardingViewModel.stepCount)"
                )
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    @ViewBuilder
    private var stepContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(stepTitle)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            switch viewModel.currentStep {
            case 0:
                personalDetails
            case 1:
                physicalDetails
            case 2:
                hockeyDetails
            case 3:
                graduationDetails
            default:
                goalsDetails
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.error)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }

    private var personalDetails: some View {
        VStack(spacing: AppSpacing.md) {
            TextField("First Name", text: $viewModel.firstName)
                .textContentType(.givenName)
                .accessibilityLabel("First name")

            TextField("Last Name", text: $viewModel.lastName)
                .textContentType(.familyName)
                .accessibilityLabel("Last name")

            DatePicker(
                "Date of Birth",
                selection: $viewModel.dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
        }
        .textFieldStyle(.roundedBorder)
        .font(AppTypography.body)
    }

    private var physicalDetails: some View {
        VStack(spacing: AppSpacing.md) {
            TextField("Height (inches)", text: $viewModel.height)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Height in inches")

            TextField("Weight (pounds)", text: $viewModel.weight)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Weight in pounds")
        }
        .textFieldStyle(.roundedBorder)
        .font(AppTypography.body)
    }

    private var hockeyDetails: some View {
        VStack(spacing: AppSpacing.md) {
            Picker("Position", selection: $viewModel.position) {
                ForEach(AthletePosition.allCases) { position in
                    Text(position.rawValue).tag(position)
                }
            }

            TextField("Team", text: $viewModel.team)
                .textContentType(.organizationName)
                .accessibilityLabel("Team")

            Picker("Shoots", selection: $viewModel.shoots) {
                ForEach(ShootingSide.allCases) { side in
                    Text(side.rawValue).tag(side)
                }
            }
            .pickerStyle(.segmented)
        }
        .textFieldStyle(.roundedBorder)
        .font(AppTypography.body)
    }

    private var graduationDetails: some View {
        Picker(
            "Graduation Year",
            selection: $viewModel.graduationYear
        ) {
            ForEach(viewModel.graduationYears, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .font(AppTypography.body)
    }

    private var goalsDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("What would you like to improve?")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)

            TextEditor(text: $viewModel.trainingGoals)
                .font(AppTypography.body)
                .frame(minHeight: 160)
                .padding(AppSpacing.sm)
                .background(AppColors.surface)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border, lineWidth: 1)
                }
                .accessibilityLabel("Training goals")
        }
    }

    private var navigation: some View {
        HStack(spacing: AppSpacing.md) {
            if !viewModel.isFirstStep {
                Button("Back") {
                    viewModel.goBack()
                }
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primary)
                .disabled(viewModel.isSaving)
            }

            Spacer()

            Button {
                if viewModel.isLastStep {
                    Task {
                        if await viewModel.save() {
                            onCompletion()
                        }
                    }
                } else {
                    viewModel.goNext()
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    }

                    Text(viewModel.isLastStep ? "Save Profile" : "Next")
                }
                .font(AppTypography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primary)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                )
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }

    private var stepTitle: String {
        switch viewModel.currentStep {
        case 0:
            "Tell us about yourself"
        case 1:
            "Physical details"
        case 2:
            "Hockey details"
        case 3:
            "Graduation year"
        default:
            "Training goals"
        }
    }
}
