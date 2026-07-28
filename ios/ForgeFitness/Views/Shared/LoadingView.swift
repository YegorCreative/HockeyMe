import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()

            Text("Loading")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading your session")
    }
}
