import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AppColors.primary
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 172, height: 172)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: AppRadius.xLarge,
                            style: .continuous
                        )
                    )
                    .shadow(
                        color: .black.opacity(0.18),
                        radius: 18,
                        x: 0,
                        y: 10
                    )
                    .accessibilityHidden(true)

                VStack(spacing: AppSpacing.sm) {
                    Text("Forge Fitness")
                        .font(AppTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Train. Track. Improve.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Forge Fitness splash screen")
    }
}
