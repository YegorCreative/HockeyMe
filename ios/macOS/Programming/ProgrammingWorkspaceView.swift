import SwiftUI

struct ProgrammingWorkspaceView: View {
    @EnvironmentObject private var store: CoachAppStore
    @State private var showArchiveConfirmation = false
    @State private var showExercisePicker = false
    @FocusState private var searchFocused: Bool

    private var visiblePrograms: [TrainingProgram] {
        store.programs.filter {
            store.searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(store.searchText)
        }
    }

    var body: some View {
        HSplitView {
            programList
                .frame(minWidth: 220, idealWidth: 260)
            weekWorkspace
                .frame(minWidth: 360, idealWidth: 480)
            workoutInspector
                .frame(minWidth: 300, idealWidth: 360)
        }
        .navigationTitle("Programming")
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search programs")
        .searchFocused($searchFocused)
        .onChange(of: store.searchFocusRequest) { _, _ in searchFocused = true }
        .toolbar {
            ToolbarItemGroup {
                Button { store.duplicateSelectedProgram() } label: {
                    Label("Duplicate", systemImage: "square.on.square")
                }
                .disabled(store.selectedProgram == nil)
                .help("Duplicate Program (⌘D)")

                Button { store.togglePublish() } label: {
                    Label(
                        store.selectedProgram?.status == .published ? "Unpublish" : "Publish",
                        systemImage: "paperplane"
                    )
                }
                .disabled(!canTogglePublish)

                Button(role: .destructive) {
                    showArchiveConfirmation = true
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .disabled(store.selectedProgram == nil)
            }
        }
        .confirmationDialog(
            "Archive this program?",
            isPresented: $showArchiveConfirmation
        ) {
            Button("Archive Program", role: .destructive) {
                store.archiveSelectedProgram()
            }
        } message: {
            Text("Assignments remain visible, but the program will no longer be current.")
        }
        .sheet(isPresented: $showExercisePicker) {
            exercisePicker
        }
    }

    private var canTogglePublish: Bool {
        guard let program = store.selectedProgram else { return false }
        return program.status == .published || program.weeks.contains { !$0.workouts.isEmpty }
    }

    private var programList: some View {
        VStack(spacing: 0) {
            List(visiblePrograms, selection: $store.selectedProgramID) { program in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(program.name).fontWeight(.medium)
                    MacStatusBadge(
                        text: program.status.rawValue.capitalized,
                        color: program.status == .published ? AppColors.success : AppColors.secondary
                    )
                }
                .tag(program.id)
                .contextMenu {
                    Button("Duplicate") { store.duplicateSelectedProgram() }
                    Button("Archive", role: .destructive) {
                        showArchiveConfirmation = true
                    }
                }
            }
            HStack {
                Button {
                    store.createPrimaryObject()
                } label: {
                    Label("New Program", systemImage: "plus")
                }
                Spacer()
            }
            .padding(AppSpacing.sm)
        }
    }

    @ViewBuilder
    private var weekWorkspace: some View {
        if let program = store.selectedProgram {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(program.name).font(AppTypography.title2.bold())
                    Text(program.description.isEmpty ? "No description" : program.description)
                        .foregroundStyle(.secondary)
                }
                .padding()

                List {
                    ForEach(program.weeks) { week in
                        Section {
                            ForEach(week.workouts) { workout in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(workout.name).fontWeight(.medium)
                                        Text("\(workout.estimatedDurationMinutes) min")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(workout.exercises.count) exercises")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.selectedWeekID = week.id
                                    store.selectedWorkoutID = workout.id
                                }
                                .contextMenu {
                                    Button("Add Exercise") {
                                        store.selectedWorkoutID = workout.id
                                        showExercisePicker = true
                                    }
                                }
                            }
                            .onMove { offsets, destination in
                                moveWorkouts(weekID: week.id, offsets: offsets, destination: destination)
                            }
                            Button("Add Workout") { store.addWorkout(to: week.id) }
                        } header: {
                            HStack {
                                Text(week.name)
                                Spacer()
                                Text(week.focus).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove(perform: moveWeeks)
                }

                HStack {
                    Button { store.addWeek() } label: {
                        Label("Add Week", systemImage: "plus")
                    }
                    Spacer()
                }
                .padding(AppSpacing.sm)
            }
        } else {
            MacEmptyDetailView(
                title: "Select a Program",
                message: "Choose a program or create one with Command-N.",
                symbol: "calendar.badge.clock"
            )
        }
    }

    @ViewBuilder
    private var workoutInspector: some View {
        if let binding = selectedWorkoutBinding {
            Form {
                Section("Workout") {
                    TextField("Name", text: binding.name)
                    TextField("Description", text: binding.description, axis: .vertical)
                    Stepper(
                        "Duration: \(binding.wrappedValue.estimatedDurationMinutes) min",
                        value: binding.estimatedDurationMinutes,
                        in: 5...240,
                        step: 5
                    )
                }
                Section("Exercises") {
                    ForEach(binding.wrappedValue.exercises) { exercise in
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(exercise.name).fontWeight(.medium)
                            Text(
                                "\(exercise.sets) × \(exercise.repsMin)–\(exercise.repsMax) · \(exercise.restSeconds)s"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Button("Add Exercise") { showExercisePicker = true }
                }
            }
            .formStyle(.grouped)
        } else {
            MacEmptyDetailView(
                title: "Select a Workout",
                message: "Select a workout to edit its existing prescription fields.",
                symbol: "sidebar.right"
            )
        }
    }

    private var selectedWorkoutBinding: Binding<ProgramWorkout>? {
        guard let programIndex = store.programs.firstIndex(where: { $0.id == store.selectedProgramID })
        else { return nil }
        for weekIndex in store.programs[programIndex].weeks.indices {
            if let workoutIndex = store.programs[programIndex].weeks[weekIndex].workouts
                .firstIndex(where: { $0.id == store.selectedWorkoutID }) {
                return $store.programs[programIndex].weeks[weekIndex].workouts[workoutIndex]
            }
        }
        return nil
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            MacSectionHeader(
                title: "Exercise Library",
                subtitle: "Select an existing hockey performance exercise."
            )
            List(sampleExerciseChoices) { exercise in
                Button {
                    guard let workoutID = store.selectedWorkoutID else { return }
                    store.addExercise(to: workoutID, exercise: exercise)
                    showExercisePicker = false
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                            Text("\(exercise.category) · \(exercise.difficulty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
    }

    private var sampleExerciseChoices: [ProgramExerciseChoice] {
        [
            ProgramExerciseChoice(id: UUID(), name: "Back Squat", category: "Strength", difficulty: "Advanced"),
            ProgramExerciseChoice(id: UUID(), name: "Trap Bar Deadlift", category: "Strength", difficulty: "Intermediate"),
            ProgramExerciseChoice(id: UUID(), name: "Copenhagen Plank", category: "Injury Resilience", difficulty: "Intermediate"),
            ProgramExerciseChoice(id: UUID(), name: "Lateral Bounds", category: "Skating Power", difficulty: "Intermediate"),
            ProgramExerciseChoice(id: UUID(), name: "Pallof Press", category: "Core", difficulty: "Beginner")
        ]
    }

    private func moveWeeks(from offsets: IndexSet, to destination: Int) {
        guard let index = store.programs.firstIndex(where: { $0.id == store.selectedProgramID }) else { return }
        store.programs[index].weeks.move(fromOffsets: offsets, toOffset: destination)
        for weekIndex in store.programs[index].weeks.indices {
            store.programs[index].weeks[weekIndex].weekNumber = weekIndex + 1
        }
    }

    private func moveWorkouts(weekID: UUID, offsets: IndexSet, destination: Int) {
        guard let programIndex = store.programs.firstIndex(where: { $0.id == store.selectedProgramID }),
              let weekIndex = store.programs[programIndex].weeks.firstIndex(where: { $0.id == weekID }) else {
            return
        }
        store.programs[programIndex].weeks[weekIndex].workouts.move(
            fromOffsets: offsets,
            toOffset: destination
        )
        for index in store.programs[programIndex].weeks[weekIndex].workouts.indices {
            store.programs[programIndex].weeks[weekIndex].workouts[index].sortOrder = index
        }
    }
}
