import SwiftUI

struct AthleteHomeView: View {
    @StateObject private var viewModel: AthleteHomeViewModel

    init(authService: AuthService) {
        _viewModel = StateObject(
            wrappedValue: AthleteHomeViewModel(authService: authService)
        )
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Athlete Home")
                .font(AppTypography.title)

            Button {
                Task {
                    await viewModel.signOut()
                }
            } label: {
                if viewModel.isSigningOut {
                    ProgressView()
                        .accessibilityLabel("Signing out")
                } else {
                    Text("Sign Out")
                }
            }
            .font(AppTypography.headline)
            .foregroundStyle(AppColors.primary)
            .disabled(viewModel.isSigningOut)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.error)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .padding(AppSpacing.lg)
    }
}
