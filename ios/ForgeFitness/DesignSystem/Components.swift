import SwiftUI

struct ForgeCard<Content: View>: View {
    let elevation: AppElevation
    let content: Content

    init(
        elevation: AppElevation = .flat,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.card)
            .background(AppColors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppRadius.medium,
                    style: .continuous
                )
            )
            .forgeElevation(elevation)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            Spacer(minLength: AppSpacing.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.onAccent)
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(AppTypography.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppSpacing.minimumTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.primary)
        .disabled(isDisabled || isLoading)
        .accessibilityValue(isLoading ? "In progress" : "")
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .font(AppTypography.headline)
            .frame(minHeight: AppSpacing.minimumTouchTarget)
        }
        .buttonStyle(.bordered)
        .tint(AppColors.primary)
        .disabled(isDisabled)
    }
}

enum StatusTone {
    case neutral
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .neutral: AppColors.textSecondary
        case .info: AppColors.info
        case .success: AppColors.success
        case .warning: AppColors.warning
        case .error: AppColors.error
        }
    }
}

struct StatusBadge: View {
    let title: String
    var tone: StatusTone = .neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(title)
        }
        .font(AppTypography.caption.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(tone.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct AvatarView: View {
    let name: String
    var image: Image?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.onAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.primary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(name)
    }

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    var detail: String?
    var systemImage: String?
    var tone: StatusTone = .info

    var body: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(tone.color)
                } else {
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(value)
                    .font(AppTypography.metric)
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var systemImage: String?
    var tone: StatusTone = .neutral

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tone.color)
                    .frame(width: AppSpacing.xl)
                    .accessibilityHidden(true)
            }
            Text(title)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
        .font(AppTypography.body)
        .frame(minHeight: AppSpacing.minimumTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

struct SearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.compact)
        .frame(minHeight: AppSpacing.minimumTouchTarget)
        .background(AppColors.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppRadius.medium,
                style: .continuous
            )
        )
    }
}

struct ToolbarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .accessibilityLabel(title)
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var label: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.border, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AppColors.primary,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            Text(label ?? "\(Int(progress * 100))%")
                .font(AppTypography.caption.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

struct ChartContainer<Content: View>: View {
    let title: String
    var subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeader(title: title, subtitle: subtitle)
                content
            }
        }
    }
}

struct WorkoutCard: View {
    let workout: Workout
    var isEmphasized = false

    var body: some View {
        ForgeCard {
            HStack(spacing: AppSpacing.md) {
                Image(
                    systemName: workout.status == .completed
                        ? "checkmark.circle.fill"
                        : "figure.strengthtraining.traditional"
                )
                .font(AppTypography.title2)
                .foregroundStyle(
                    workout.status == .completed
                        ? AppColors.success
                        : AppColors.primary
                )
                .frame(width: AppSpacing.xl)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(workout.title)
                        .font(AppTypography.headline)
                    Text(
                        "\(workout.estimatedDurationMinutes) min • \(workout.scheduledDate.formatted(date: .abbreviated, time: .omitted))"
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "chevron.forward")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            if isEmphasized {
                RoundedRectangle(
                    cornerRadius: AppRadius.medium,
                    style: .continuous
                )
                .stroke(AppColors.primary, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AthleteCard: View {
    let athlete: Athlete

    var body: some View {
        ForgeCard {
            HStack(spacing: AppSpacing.md) {
                AvatarView(
                    name: "\(athlete.firstName) \(athlete.lastName)"
                )
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("\(athlete.firstName) \(athlete.lastName)")
                        .font(AppTypography.headline)
                    Text(
                        "\(athlete.position.rawValue) • \(athlete.team)"
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
        }
    }
}

struct TestingCard: View {
    let title: String
    let date: Date
    var detail: String?
    var status: String?

    var body: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text(title)
                        .font(AppTypography.headline)
                    Spacer()
                    if let status {
                        StatusBadge(title: status, tone: .info)
                    }
                }
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                if let detail {
                    Text(detail)
                        .font(AppTypography.body)
                }
            }
        }
    }
}

struct LoadingIndicator: View {
    var label = "Loading"

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .controlSize(.large)
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SkeletonView: View {
    var height: CGFloat = 16

    var body: some View {
        RoundedRectangle(
            cornerRadius: AppRadius.small,
            style: .continuous
        )
        .fill(AppColors.border.opacity(0.35))
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct ForgeEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
    }
}

struct ForgeErrorState: View {
    let title: String
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Try Again", action: retry)
            }
        }
    }
}

struct ForgeSuccessState: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)
        } description: {
            Text(message)
        }
    }
}
