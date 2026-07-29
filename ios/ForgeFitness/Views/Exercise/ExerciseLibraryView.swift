import SwiftUI

struct ExerciseLibraryView: View {
    @StateObject private var viewModel: ExerciseLibraryViewModel

    init(service: ExerciseService) {
        _viewModel = StateObject(
            wrappedValue: ExerciseLibraryViewModel(service: service)
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                performanceHeader
                categoryFilters

                Text("\(viewModel.exercises.count) Exercises")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if viewModel.exercises.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.exercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            ExerciseLibraryRow(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens exercise coaching details")
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Exercise or muscle"
        )
        .refreshable {
            await viewModel.refresh()
        }
        .overlay {
            if viewModel.isLoading && viewModel.exercises.isEmpty {
                LoadingView().background(AppColors.background)
            } else if let error = viewModel.errorMessage,
                      viewModel.exercises.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Exercise Library Unavailable",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.refresh() }
                    }
                }
                .background(AppColors.background)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var performanceHeader: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "hockey.puck.fill")
                .font(AppTypography.largeTitle)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Built for the Ice")
                    .font(AppTypography.title)
                    .fontWeight(.bold)

                Text("Movements selected for stronger strides, faster transitions, and durable athletes.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .accessibilityElement(children: .combine)
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                filterButton(title: "All", category: nil)

                ForEach(viewModel.categories) { category in
                    filterButton(
                        title: category.rawValue,
                        category: category
                    )
                }
            }
        }
        .accessibilityLabel("Hockey performance categories")
    }

    private func filterButton(
        title: String,
        category: HockeyExerciseCategory?
    ) -> some View {
        let isSelected = viewModel.selectedCategory == category

        return Button(title) {
            viewModel.select(category)
        }
        .font(AppTypography.caption)
        .fontWeight(.semibold)
        .foregroundStyle(
            isSelected ? .white : AppColors.textPrimary
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            isSelected ? AppColors.primary : AppColors.surface
        )
        .clipShape(Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHidden(true)

            Text("No exercises found")
                .font(AppTypography.headline)

            Text("Try another movement, muscle, or performance category.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .accessibilityElement(children: .combine)
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColors.primary.opacity(0.12))

                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(AppColors.primary)
                    .accessibilityHidden(true)
            }
            .frame(
                width: AppSpacing.xl + AppSpacing.md,
                height: AppSpacing.xl + AppSpacing.md
            )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(exercise.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(exercise.hockeyCategory.rawValue)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)

                Text(
                    exercise.primaryMuscles
                        .map(\.rawValue)
                        .joined(separator: " · ")
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text(exercise.difficulty.rawValue)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(exercise.name), \(exercise.hockeyCategory.rawValue), \(exercise.difficulty.rawValue)"
        )
    }
}
