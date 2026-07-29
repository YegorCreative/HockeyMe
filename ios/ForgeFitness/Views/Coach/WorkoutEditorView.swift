import SwiftUI

struct WorkoutEditorView: View {
    let weekID: UUID
    let workoutID: UUID
    @ObservedObject var viewModel: ProgramEditorViewModel
    @State private var draft: ProgramWorkout?
    @State private var showingExercisePicker = false

    private var workout: ProgramWorkout? {
        viewModel.program?.weeks.first { $0.id == weekID }?
            .workouts.first { $0.id == workoutID }
    }

    var body: some View {
        List {
            if let draft {
                Section("Workout Details") {
                    TextField(
                        "Workout Name",
                        text: binding(\.name, default: "")
                    )
                    TextField(
                        "Description",
                        text: binding(\.description, default: ""),
                        axis: .vertical
                    )
                    Stepper(
                        "Estimated Duration: \(draft.estimatedDurationMinutes) min",
                        value: binding(
                            \.estimatedDurationMinutes,
                            default: 45
                        ),
                        in: 5...240,
                        step: 5
                    )
                    Button("Save Workout") {
                        Task {
                            await viewModel.saveWorkout(
                                draft,
                                weekID: weekID
                            )
                        }
                    }
                }

                Section("Exercises") {
                    if draft.exercises.isEmpty {
                        Text("No exercises added.")
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    ForEach(draft.exercises) { exercise in
                        PrescriptionEditorRow(
                            exercise: exercise,
                            onSave: { updated in
                                Task {
                                    await viewModel.saveExercise(
                                        updated,
                                        workoutID: workoutID,
                                        weekID: weekID
                                    )
                                    syncDraft()
                                }
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteExercise(
                                        exercise,
                                        workoutID: workoutID,
                                        weekID: weekID
                                    )
                                    syncDraft()
                                }
                            },
                            onMove: { offset in
                                Task {
                                    await viewModel.moveExercise(
                                        exercise,
                                        workoutID: workoutID,
                                        weekID: weekID,
                                        by: offset
                                    )
                                    syncDraft()
                                }
                            }
                        )
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label(
                            "Add Exercise",
                            systemImage: "plus"
                        )
                    }
                }

                Section {
                    Button("Delete Workout", role: .destructive) {
                        Task {
                            await viewModel.deleteWorkout(
                                draft,
                                weekID: weekID
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(workout?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(
                exercises: viewModel.exerciseChoices
            ) { exercise in
                Task {
                    await viewModel.addExercise(
                        exercise,
                        workoutID: workoutID,
                        weekID: weekID
                    )
                    syncDraft()
                }
                showingExercisePicker = false
            }
        }
        .onAppear { syncDraft() }
        .onChange(of: workout?.exercises.count) {
            syncDraft()
        }
    }

    private func syncDraft() {
        draft = workout
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<ProgramWorkout, Value>,
        default defaultValue: Value
    ) -> Binding<Value> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? defaultValue },
            set: { draft?[keyPath: keyPath] = $0 }
        )
    }
}

private struct PrescriptionEditorRow: View {
    @State var exercise: ProgramExercise
    let onSave: (ProgramExercise) -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void

    var body: some View {
        DisclosureGroup(exercise.name) {
            Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...20)
            Stepper(
                "Reps: \(exercise.repsMin)–\(exercise.repsMax)",
                value: $exercise.repsMin,
                in: 1...exercise.repsMax
            )
            Stepper(
                "Maximum Reps: \(exercise.repsMax)",
                value: $exercise.repsMax,
                in: exercise.repsMin...100
            )
            Stepper(
                "Rest: \(exercise.restSeconds) sec",
                value: $exercise.restSeconds,
                in: 0...600,
                step: 15
            )
            TextField("Tempo", text: $exercise.tempo)
            TextField("Notes", text: $exercise.notes, axis: .vertical)
            TextField(
                "Coach Cues",
                text: $exercise.coachCues,
                axis: .vertical
            )

            HStack {
                Button("Move Up") { onMove(-1) }
                Button("Move Down") { onMove(1) }
            }
            Button("Save Exercise") { onSave(exercise) }
            Button("Remove Exercise", role: .destructive) {
                onDelete()
            }
        }
        .accessibilityHint("Expands exercise prescription settings")
    }
}
