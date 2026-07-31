import SwiftUI

struct MacMetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: symbol)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.metric)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
    }
}

struct MacSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppTypography.title2.bold())
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MacStatusBadge: View {
    let text: String
    var color: Color = AppColors.secondary

    var body: some View {
        Text(text)
            .font(AppTypography.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityLabel("Status: \(text)")
    }
}

struct MacEmptyDetailView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MacErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Forge Coach Unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.sm)
    }
}

struct MacStatRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value)
            .font(AppTypography.body)
    }
}
