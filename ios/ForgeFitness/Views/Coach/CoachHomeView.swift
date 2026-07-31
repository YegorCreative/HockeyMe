import SwiftUI

struct CoachHomeView: View {
    @StateObject private var viewModel: CoachHomeViewModel
    private let programRepository: ProgramRepository
    private let testingRepository: TestingRepository?
    private let athleteService: AthleteService
    private let organizationRepository: OrganizationRepository?

    init(
        athleteService: AthleteService,
        programRepository: ProgramRepository,
        testingRepository: TestingRepository?,
        organizationRepository: OrganizationRepository?
    ) {
        self.athleteService = athleteService
        self.programRepository = programRepository
        self.testingRepository = testingRepository
        self.organizationRepository = organizationRepository
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

            Group {
                if let testingRepository {
                    TestingDashboardView(
                        role: .coach,
                        repository: testingRepository,
                        athleteService: athleteService
                    )
                }
            }
                .tabItem {
                    Label("Testing", systemImage: "stopwatch.fill")
                }

            Group {
                if let organizationRepository {
                    OrganizationDashboardView(
                        repository: organizationRepository
                    )
                }
            }
                .tabItem {
                    Label("Organization", systemImage: "building.2.fill")
                }
        }
        .tint(AppColors.primary)
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}
