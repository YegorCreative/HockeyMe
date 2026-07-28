import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xl)

                logo
                header
                form
                actions
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(AppColors.primary)

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 88, height: 88)
        .accessibilityElement()
        .accessibilityLabel("Forge Fitness logo")
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Forge Fitness")
                .font(AppTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Train. Track. Improve.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        VStack(spacing: AppSpacing.md) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Email address")

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .accessibilityLabel("Password")
        }
        .font(AppTypography.body)
        .textFieldStyle(.plain)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.border, lineWidth: 1)
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.md) {
            Button("Sign In") {}
                .font(AppTypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                .accessibilityHint("Authentication is not available yet")

            Button("Forgot Password?") {}
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondary)
                .accessibilityHint("Password recovery is not available yet")

            Button("Create Account") {}
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primary)
                .accessibilityHint("Account creation is not available yet")
        }
    }
}
