import SwiftUI

struct ProgramEditorView: View {
    @StateObject private var viewModel: ProgramEditorViewModel
    @State private var name = ""
    @State private var description = ""

    init(programID: UUID, repository: ProgramRepository) {
        _viewModel = StateObject(
            wrappedValue: ProgramEditorViewModel(
                programID: programID,
                repository: repository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.program == nil {
                LoadingView()
            } else if let program = viewModel.program {
                List {
                    Section("Program") {
                        TextField("Program Name", text: $name)
                        TextField(
                            "Description",
                            text: $description,
                            axis: .vertical
                        )
                        .lineLimit(3...6)

                        Button("Save Program Details") {
                            viewModel.program?.name = name
                            viewModel.program?.description = description
                            Task { await viewModel.saveProgram() }
                        }
                        .disabled(
                            name.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty || viewModel.isSaving
                        )
                    }

                    Section("Weeks") {
                        if program.weeks.isEmpty {
                            Text("No weeks added.")
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        ForEach(program.weeks) { week in
                            HStack {
                                NavigationLink {
                                    WeekEditorView(
                                        weekID: week.id,
                                        viewModel: viewModel
                                    )
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(week.name)
                                        Text(
                                            "\(week.workouts.count) workouts"
                                        )
                                        .font(AppTypography.caption)
                                        .foregroundStyle(
                                            AppColors.textSecondary
                                        )
                                    }
                                }

                                reorderButtons {
                                    await viewModel.moveWeek(week, by: -1)
                                } down: {
                                    await viewModel.moveWeek(week, by: 1)
                                }
                            }
                        }

                        Button {
                            Task { await viewModel.addWeek() }
                        } label: {
                            Label("Add Week", systemImage: "plus")
                        }
                    }

                    Section("Management") {
                        Button(
                            program.status == .published
                                ? "Unpublish Program"
                                : "Publish Program"
                        ) {
                            Task {
                                await viewModel.setPublished(
                                    program.status != .published
                                )
                            }
                        }
                        .disabled(
                            (program.status != .published
                                && !viewModel.canPublish)
                                || viewModel.isSaving
                        )

                        NavigationLink {
                            AthleteAssignmentView(
                                program: program,
                                repository: viewModel.repository
                            )
                        } label: {
                            Label(
                                "Athlete Assignments",
                                systemImage: "person.badge.plus"
                            )
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(AppColors.error)
                                .accessibilityLabel("Error: \(error)")
                        }
                    }
                }
                .refreshable {
                    await viewModel.load()
                    syncFields()
                }
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label(
                        "Program Unavailable",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle("Program Editor")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            syncFields()
        }
    }

    private func syncFields() {
        guard let program = viewModel.program else { return }
        name = program.name
        description = program.description
    }

    private func reorderButtons(
        up: @escaping @MainActor () async -> Void,
        down: @escaping @MainActor () async -> Void
    ) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Button {
                Task { await up() }
            } label: {
                Image(systemName: "chevron.up")
            }
            Button {
                Task { await down() }
            } label: {
                Image(systemName: "chevron.down")
            }
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reorder")
    }
}
