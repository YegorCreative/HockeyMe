import SwiftUI

struct CoachHomeView: View {
    @StateObject private var viewModel: CoachHomeViewModel
    private let programRepository: ProgramRepository

    init(
        athleteService: AthleteService,
        programRepository: ProgramRepository
    ) {
        self.programRepository = programRepository
        _viewModel = StateObject(
            wrappedValue: CoachHomeViewModel(
                athleteService: athleteService
            )
        )
    }

    var body: some View {
        TabView {
            CoachDashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
                }

            AthleteListView(viewModel: viewModel)
                .tabItem {
                    Label("Athletes", systemImage: "person.3.fill")
                }

            ProgramListView(repository: programRepository)
                .tabItem {
                    Label("Programs", systemImage: "list.clipboard.fill")
                }
        }
        .tint(AppColors.primary)
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}
