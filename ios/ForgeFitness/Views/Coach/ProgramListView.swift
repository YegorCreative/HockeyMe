import SwiftUI

struct ProgramListView: View {
    @StateObject private var viewModel: ProgramListViewModel

    init(repository: ProgramRepository) {
        _viewModel = StateObject(
            wrappedValue: ProgramListViewModel(repository: repository)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.programs) { program in
                    NavigationLink {
                        ProgramEditorView(
                            programID: program.id,
                            repository: viewModel.repository
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(program.name)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Text(
                                "\(program.durationWeeks) weeks • \(statusTitle(program.status))"
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .accessibilityElement(children: .combine)
                    }
                    .contextMenu {
                        Button {
                            Task { await viewModel.duplicate(program) }
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Button {
                            Task { await viewModel.archive(program) }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { _ = await viewModel.createProgram() }
                    } label: {
                        Label("Create Program", systemImage: "plus")
                    }
                    .accessibilityHint("Creates a new draft program")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.programs.isEmpty {
                    LoadingView().background(AppColors.background)
                } else if let error = viewModel.errorMessage,
                          viewModel.programs.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "Programs Unavailable",
                            systemImage: "exclamationmark.triangle"
                        )
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.refresh() }
                        }
                    }
                } else if viewModel.programs.isEmpty {
                    ContentUnavailableView(
                        "No Programs",
                        systemImage: "list.clipboard",
                        description: Text(
                            "Create a program to begin building training."
                        )
                    )
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private func statusTitle(
        _ status: TrainingProgramStatus
    ) -> String {
        switch status {
        case .draft: "Draft"
        case .published: "Published"
        case .archived: "Archived"
        }
    }
}
