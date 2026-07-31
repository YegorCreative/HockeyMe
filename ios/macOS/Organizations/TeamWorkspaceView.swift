import SwiftUI

struct TeamWorkspaceView: View {
    @EnvironmentObject private var store: CoachAppStore
    @State private var selection = Set<UUID>()
    @FocusState private var searchFocused: Bool

    private var teams: [OrganizationTeam] {
        store.teams.filter {
            store.searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(store.searchText)
        }
    }

    var body: some View {
        Group {
            if teams.isEmpty {
                MacEmptyDetailView(
                    title: "No Teams",
                    message: "Create a team with Command-N.",
                    symbol: "person.3"
                )
            } else {
                Table(teams, selection: $selection) {
                    TableColumn("Team") { Text($0.name).fontWeight(.medium) }
                    TableColumn("Age Group") { Text($0.ageGroup) }
                    TableColumn("Status") {
                        MacStatusBadge(
                            text: $0.isArchived ? "Archived" : "Active",
                            color: $0.isArchived ? AppColors.textSecondary : AppColors.success
                        )
                    }
                    TableColumn("Athletes") { team in
                        Text(String(store.athletes.filter { $0.team == team.name }.count))
                    }
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    Button("Archive Team") {
                        for id in ids {
                            if let index = store.teams.firstIndex(where: { $0.id == id }) {
                                store.teams[index].isArchived = true
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Teams")
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search teams")
        .searchFocused($searchFocused)
        .onChange(of: store.searchFocusRequest) { _, _ in searchFocused = true }
    }
}
