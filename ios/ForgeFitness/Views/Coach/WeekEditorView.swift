import SwiftUI

struct WeekEditorView: View {
    let weekID: UUID
    @ObservedObject var viewModel: ProgramEditorViewModel
    @State private var name = ""
    @State private var focus = ""

    private var week: TrainingProgramWeek? {
        viewModel.program?.weeks.first { $0.id == weekID }
    }

    var body: some View {
        List {
            if let week {
                Section("Week Details") {
                    TextField("Week Name", text: $name)
                    TextField("Focus", text: $focus)
                    Button("Save Week") {
                        var updated = week
                        updated.name = name
                        updated.focus = focus
                        Task { await viewModel.saveWeek(updated) }
                    }
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }

                Section("Workouts") {
                    if week.workouts.isEmpty {
                        Text("No workouts added.")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    ForEach(week.workouts) { workout in
                        HStack {
                            NavigationLink {
                                WorkoutEditorView(
                                    weekID: week.id,
                                    workoutID: workout.id,
                                    viewModel: viewModel
                                )
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(workout.name)
                                    Text(
                                        "\(workout.estimatedDurationMinutes) min"
                                    )
                                    .font(AppTypography.caption)
                                    .foregroundStyle(
                                        AppColors.textSecondary
                                    )
                                }
                            }

                            VStack {
                                Button {
                                    Task {
                                        await viewModel.moveWorkout(
                                            workout,
                                            weekID: week.id,
                                            by: -1
                                        )
                                    }
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                Button {
                                    Task {
                                        await viewModel.moveWorkout(
                                            workout,
                                            weekID: week.id,
                                            by: 1
                                        )
                                    }
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Reorder \(workout.name)")
                        }
                    }

                    Button {
                        Task { await viewModel.addWorkout(to: week) }
                    } label: {
                        Label("Add Workout", systemImage: "plus")
                    }
                }

                Section {
                    Button("Delete Week", role: .destructive) {
                        Task { await viewModel.deleteWeek(week) }
                    }
                }
            }
        }
        .navigationTitle(week?.name ?? "Week")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = week?.name ?? ""
            focus = week?.focus ?? ""
        }
    }
}
