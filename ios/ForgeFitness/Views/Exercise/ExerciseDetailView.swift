import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                movementProfile
                video

                NumberedDetailSection(
                    title: "How to Perform",
                    items: exercise.instructions
                )

                BulletDetailSection(
                    title: "Common Mistakes",
                    symbol: "exclamationmark.triangle.fill",
                    color: AppColors.error,
                    items: exercise.commonMistakes
                )

                BulletDetailSection(
                    title: "Coach Tips",
                    symbol: "quote.bubble.fill",
                    color: AppColors.secondary,
                    items: exercise.coachTips
                )

                substitutions
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label(
                exercise.hockeyCategory.rawValue,
                systemImage: "hockey.puck.fill"
            )
            .font(AppTypography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppColors.secondary)

            Text(exercise.name)
                .font(AppTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                tag(exercise.category.rawValue)
                tag(exercise.difficulty.rawValue)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var movementProfile: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Movement Profile")
                .font(AppTypography.headline)
                .accessibilityAddTraits(.isHeader)

            profileRow(
                title: "Primary",
                values: exercise.primaryMuscles.map(\.rawValue)
            )
            profileRow(
                title: "Secondary",
                values: exercise.secondaryMuscles.map(\.rawValue)
            )
            profileRow(
                title: "Equipment",
                values: exercise.equipment.map(\.rawValue)
            )
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }

    @ViewBuilder
    private var video: some View {
        if let videoURL = exercise.videoURL {
            Link(destination: videoURL) {
                Label("Watch Technique Video", systemImage: "play.circle.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.primary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                    )
            }
            .accessibilityHint("Opens the exercise video")
        }
    }

    private var substitutions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Exercise Substitutions")
                .font(AppTypography.headline)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(exercise.substitutions, id: \.self) { item in
                    tag(item)
                }
            }
        }
    }

    private func profileRow(
        title: String,
        values: [String]
    ) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .frame(
                    width: AppSpacing.xl
                        + AppSpacing.xl
                        + AppSpacing.sm,
                    alignment: .leading
                )

            Text(values.joined(separator: ", "))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .fontWeight(.medium)
            .foregroundStyle(AppColors.primary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.primary.opacity(0.1))
            .clipShape(Capsule())
    }
}

private struct NumberedDetailSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Text(String(index + 1))
                        .font(AppTypography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                        .background(AppColors.primary)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(item)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1): \(item)")
            }
        }
    }
}

private struct BulletDetailSection: View {
    let title: String
    let symbol: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(items, id: \.self) { item in
                Label {
                    Text(item)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrangement(
            proposal: proposal,
            subviews: subviews
        ).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrangement(
            proposal: proposal,
            subviews: subviews
        )

        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + point.x,
                    y: bounds.minY + point.y
                ),
                proposal: .unspecified
            )
        }
    }

    private func arrangement(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var position = CGPoint.zero
        var lineHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if position.x + size.width > maxWidth,
               position.x > 0 {
                position.x = 0
                position.y += lineHeight + spacing
                lineHeight = 0
            }

            points.append(position)
            position.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            contentWidth = max(contentWidth, position.x - spacing)
        }

        return (
            CGSize(
                width: min(contentWidth, maxWidth),
                height: position.y + lineHeight
            ),
            points
        )
    }
}
