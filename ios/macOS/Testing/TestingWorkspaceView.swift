import SwiftUI

struct TestingWorkspaceView: View {
    @EnvironmentObject private var store: CoachAppStore
    @State private var selectedProtocolID: UUID?
    @State private var selectedSessionIDs = Set<UUID>()
    @FocusState private var searchFocused: Bool

    private var visibleSessions: [TestingSession] {
        store.testingSessions.filter {
            store.searchText.isEmpty ||
            $0.athleteName.localizedCaseInsensitiveContains(store.searchText) ||
            $0.protocolName.localizedCaseInsensitiveContains(store.searchText)
        }
    }

    var body: some View {
        HSplitView {
            List(store.protocols, selection: $selectedProtocolID) { testingProtocol in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(testingProtocol.name).fontWeight(.medium)
                    Text("Version \(testingProtocol.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(testingProtocol.id)
                .contextMenu {
                    Button("Duplicate") {
                        duplicate(testingProtocol)
                    }
                }
            }
            .frame(minWidth: 220, idealWidth: 260)

            Group {
                if visibleSessions.isEmpty {
                    MacEmptyDetailView(
                        title: "No Testing Sessions",
                        message: "No testing sessions match the current search.",
                        symbol: "gauge.with.dots.needle.67percent"
                    )
                } else {
                    Table(visibleSessions, selection: $selectedSessionIDs) {
                        TableColumn("Athlete") { Text($0.athleteName).fontWeight(.medium) }
                        TableColumn("Protocol") { Text($0.protocolName) }
                        TableColumn("Season") { Text($0.seasonLabel) }
                        TableColumn("Scheduled") {
                            Text($0.scheduledAt, format: .dateTime.month().day().year())
                        }
                        TableColumn("Status") {
                            MacStatusBadge(
                                text: $0.status.rawValue.capitalized,
                                color: $0.status == .completed ? AppColors.success : AppColors.secondary
                            )
                        }
                    }
                }
            }
            .frame(minWidth: 560)
        }
        .navigationTitle("Testing")
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search testing")
        .searchFocused($searchFocused)
        .onChange(of: store.searchFocusRequest) { _, _ in searchFocused = true }
        .inspector(isPresented: .constant(!selectedSessionIDs.isEmpty)) {
            testingInspector
                .inspectorColumnWidth(min: 280, ideal: 340, max: 440)
        }
    }

    @ViewBuilder
    private var testingInspector: some View {
        if let id = selectedSessionIDs.first,
           let session = store.testingSessions.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(session.athleteName).font(AppTypography.title2.bold())
                    Text(session.protocolName).foregroundStyle(.secondary)
                    Divider()
                    InspectorSection(title: "Results") {
                        ForEach(aggregatedResults(session.results), id: \.name) { row in
                            MacStatRow(title: row.name, value: "\(row.value.formatted()) \(row.unit)")
                        }
                    }
                    Divider()
                    InspectorSection(title: "Session") {
                        MacStatRow(title: "Position", value: session.athletePosition)
                        MacStatRow(title: "Season", value: session.seasonLabel)
                        MacStatRow(title: "Location", value: session.location)
                    }
                }
                .padding()
            }
        } else {
            MacEmptyDetailView(
                title: "Select a Session",
                message: "Choose a session to inspect results.",
                symbol: "list.bullet.rectangle"
            )
        }
    }

    private func duplicate(_ source: TestingProtocol) {
        store.protocols.insert(
            TestingProtocol(
                coachUserID: source.coachUserID,
                parentProtocolID: source.id,
                name: "\(source.name) Copy",
                description: source.description,
                version: source.version + 1,
                status: .draft,
                allowsAthleteEntry: source.allowsAthleteEntry,
                metrics: source.metrics
            ),
            at: 0
        )
    }

    private func aggregatedResults(
        _ results: [TestingResult]
    ) -> [(name: String, value: Double, unit: String)] {
        let grouped = Dictionary(grouping: results, by: \.metricID)
        return grouped.values.compactMap { values in
            guard let latest = values.max(by: { $0.recordedAt < $1.recordedAt }) else { return nil }
            return (latest.metricName, latest.value, latest.unit)
        }
        .sorted { $0.name < $1.name }
    }
}

struct AnalyticsWorkspaceView: View {
    @EnvironmentObject private var store: CoachAppStore

    private var completedResults: [TestingResult] {
        store.testingSessions
            .filter { $0.status == .completed }
            .flatMap(\.results)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                MacSectionHeader(
                    title: "Analytics",
                    subtitle: "Repository-derived testing and assignment summaries"
                )
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: AppSpacing.md)],
                    spacing: AppSpacing.md
                ) {
                    MacMetricCard(
                        title: "Completed Results",
                        value: "\(completedResults.count)",
                        symbol: "checkmark.circle"
                    )
                    MacMetricCard(
                        title: "Program Coverage",
                        value: "\(store.dashboard.assignedAthletes)/\(store.dashboard.athleteCount)",
                        symbol: "person.crop.circle.badge.checkmark"
                    )
                    MacMetricCard(
                        title: "Active Protocols",
                        value: "\(store.protocols.filter { $0.status == .active }.count)",
                        symbol: "gauge.with.dots.needle.67percent"
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
        .navigationTitle("Analytics")
    }
}
