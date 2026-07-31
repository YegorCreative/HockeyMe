import SwiftUI

struct CoachShellView: View {
    @EnvironmentObject private var store: CoachAppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            List(CoachSection.allCases, selection: $store.selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
                    .accessibilityHint("Command \(CoachSection.allCases.firstIndex(of: section)! + 1)")
            }
            .navigationTitle("Forge Coach")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) {
#if DEBUG
                HStack {
                    MacStatusBadge(text: "COACH", color: AppColors.primary)
                    if store.isInMemory {
                        MacStatusBadge(text: "DEVELOPER", color: AppColors.warning)
                    }
                }
                .padding()
#endif
            }
        } detail: {
            section
                .id(store.selection)
                .transition(reduceMotion ? .identity : .opacity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.focusSearch()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .help("Find (⌘F)")

                Button {
                    store.createPrimaryObject()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .disabled(![.programming, .testing, .teams].contains(store.selection))
                .help("Create in current section (⌘N)")
            }
        }
    }

    @ViewBuilder
    private var section: some View {
        switch store.selection {
        case .dashboard: CoachDashboardView()
        case .athletes: AthleteWorkspaceView()
        case .teams: TeamWorkspaceView()
        case .programming: ProgrammingWorkspaceView()
        case .testing: TestingWorkspaceView()
        case .analytics: AnalyticsWorkspaceView()
        case .organization: OrganizationWorkspaceView()
        case .settings: CoachSettingsView()
        }
    }
}
