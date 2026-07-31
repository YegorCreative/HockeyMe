import SwiftUI

struct AthleteWorkspaceView: View {
    @EnvironmentObject private var store: CoachAppStore
    @State private var teamFilter = "All Teams"
    @State private var positionFilter = "All Positions"
    @State private var seasonFilter = "All Seasons"
    @State private var sortOrder = [KeyPathComparator(\CoachAthleteRecord.lastName)]
    @FocusState private var searchFocused: Bool

    private var filteredAthletes: [CoachAthleteRecord] {
        store.athletes
            .filter {
                (teamFilter == "All Teams" || $0.team == teamFilter) &&
                (positionFilter == "All Positions" || $0.position == positionFilter) &&
                (seasonFilter == "All Seasons" || $0.season == seasonFilter) &&
                (store.searchText.isEmpty ||
                 $0.name.localizedCaseInsensitiveContains(store.searchText))
            }
            .sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            filters
                .frame(minWidth: 170, idealWidth: 200, maxWidth: 240)

            Group {
                if filteredAthletes.isEmpty {
                    MacEmptyDetailView(
                        title: "No Athletes",
                        message: "No athletes match the current search and filters.",
                        symbol: "person.2.slash"
                    )
                } else {
                    Table(
                        filteredAthletes,
                        selection: $store.selectedAthleteIDs,
                        sortOrder: $sortOrder
                    ) {
                        TableColumn("Name", value: \.lastName) { athlete in
                            Text(athlete.name)
                                .fontWeight(.medium)
                        }
                        TableColumn("Team", value: \.team)
                        TableColumn("Position", value: \.position)
                        TableColumn("Grad", value: \.graduationYear) {
                            Text(String($0.graduationYear))
                        }
                        TableColumn("Program") { athlete in
                            let programName = athlete.programName
                            Text(programName ?? "Unassigned")
                                .foregroundStyle(programName == nil ? Color.secondary : Color.primary)
                        }
                        TableColumn("Training", value: \.trainingStatus)
                    }
                    .contextMenu(forSelectionType: UUID.self) { ids in
                        if ids.count == 1 {
                            Button("Open Athlete") {
                                store.selectedAthleteIDs = ids
                            }
                        }
                        if store.selectedProgram != nil {
                            Button("Assign Selected Program") {
                                ids.forEach(store.assignSelectedProgram)
                            }
                        }
                    } primaryAction: { ids in
                        store.selectedAthleteIDs = ids
                    }
                }
            }
            .frame(minWidth: 520)
        }
        .navigationTitle("Athletes")
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search athletes")
        .searchFocused($searchFocused)
        .onChange(of: store.searchFocusRequest) { _, _ in searchFocused = true }
        .inspector(isPresented: .constant(!store.selectedAthleteIDs.isEmpty)) {
            athleteInspector
                .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
        }
    }

    private var filters: some View {
        Form {
            Section("Team") {
                Picker("Team", selection: $teamFilter) {
                    Text("All Teams").tag("All Teams")
                    ForEach(Set(store.athletes.map(\.team)).sorted(), id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .labelsHidden()
            }
            Section("Season") {
                Picker("Season", selection: $seasonFilter) {
                    Text("All Seasons").tag("All Seasons")
                    ForEach(Set(store.athletes.map(\.season)).sorted(), id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .labelsHidden()
            }
            Section("Position") {
                Picker("Position", selection: $positionFilter) {
                    Text("All Positions").tag("All Positions")
                    ForEach(Set(store.athletes.map(\.position)).sorted(), id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var athleteInspector: some View {
        if let id = store.selectedAthleteIDs.first,
           let athlete = store.athletes.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(athlete.name).font(AppTypography.title2.bold())
                    MacStatusBadge(text: athlete.trainingStatus)
                    Divider()
                    InspectorSection(title: "Profile") {
                        MacStatRow(title: "Team", value: athlete.team)
                        MacStatRow(title: "Position", value: athlete.position)
                        MacStatRow(title: "Graduation", value: String(athlete.graduationYear))
                        MacStatRow(title: "Season", value: athlete.season)
                    }
                    Divider()
                    InspectorSection(title: "Current Program") {
                        Text(athlete.programName ?? "No active assignment")
                            .foregroundStyle(athlete.programName == nil ? .secondary : .primary)
                    }
                    Divider()
                    InspectorSection(title: "Testing") {
                        Text(athlete.testingSummary)
                    }
                }
                .padding()
            }
        } else {
            MacEmptyDetailView(
                title: "Select an Athlete",
                message: "Choose an athlete to review their coach-visible profile.",
                symbol: "person.crop.rectangle"
            )
        }
    }
}
