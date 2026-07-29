import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [ProgramExerciseChoice]
    let onSelect: (ProgramExerciseChoice) -> Void
    @State private var searchText = ""

    private var filteredExercises: [ProgramExerciseChoice] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.category.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button {
                    onSelect(exercise)
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(exercise.name)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(
                            "\(exercise.category) • \(exercise.difficulty)"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .accessibilityHint("Adds exercise to workout")
            }
            .overlay {
                if filteredExercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text(
                            exercises.isEmpty
                                ? "The exercise library is empty."
                                : "Try another search."
                        )
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
