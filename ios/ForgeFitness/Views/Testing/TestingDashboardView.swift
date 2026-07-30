import Charts
import SwiftUI

struct TestingDashboardView: View {
    @StateObject private var viewModel: TestingDashboardViewModel
    @State private var editorProtocol: TestingProtocol?
    @State private var presentsNewProtocol = false
    @State private var schedulingProtocol: TestingProtocol?

    init(
        role: TestingViewerRole,
        repository: TestingRepository,
        athleteService: AthleteService
    ) {
        _viewModel = StateObject(
            wrappedValue: TestingDashboardViewModel(
                role: role,
                repository: repository,
                athleteService: athleteService
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let sync = viewModel.syncMessage {
                        Label(sync, systemImage: "arrow.triangle.2.circlepath")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityLabel("Sync status: \(sync)")
                    }

                    if viewModel.role == .coach {
                        coachOverview
                        protocolSection
                    } else {
                        athleteOverview
                    }

                    upcomingSection
                    historySection
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Testing")
            .toolbar {
                if viewModel.role == .coach {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            presentsNewProtocol = true
                        } label: {
                            Label("New Protocol", systemImage: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage,
                          viewModel.sessions.isEmpty,
                          viewModel.protocols.isEmpty {
                    ContentUnavailableView {
                        Label(
                            "Testing Unavailable",
                            systemImage: "exclamationmark.triangle"
                        )
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.retry() }
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $presentsNewProtocol) {
            TestingProtocolEditorView(
                repository: viewModel.repositoryForEditor,
                onSaved: {
                    presentsNewProtocol = false
                    Task { await viewModel.refresh() }
                }
            )
        }
        .sheet(item: $editorProtocol) { value in
            TestingProtocolEditorView(
                protocolValue: value,
                repository: viewModel.repositoryForEditor,
                onSaved: {
                    editorProtocol = nil
                    Task { await viewModel.refresh() }
                }
            )
        }
        .sheet(item: $schedulingProtocol) { value in
            TestingScheduleView(
                protocolValue: value,
                athletes: viewModel.athletes
            ) { athleteIDs, date, season, location in
                await viewModel.schedule(
                    protocolValue: value,
                    athleteIDs: athleteIDs,
                    date: date,
                    season: season,
                    location: location
                )
                schedulingProtocol = nil
            }
        }
    }

    private var coachOverview: some View {
        let summary = viewModel.coachSummary
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Team Overview")
                .font(AppTypography.title)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: AppSpacing.md) {
                testingCard(
                    title: "Completion",
                    value: "\(Int(summary.completionPercent.rounded()))%"
                )
                testingCard(
                    title: "Missing",
                    value: "\(summary.missingTestCount)"
                )
            }

            if !summary.strongestAthletes.isEmpty {
                testingListCard(
                    title: "Strongest Athletes",
                    values: summary.strongestAthletes
                )
            }
            if !summary.mostImprovedAthletes.isEmpty {
                testingListCard(
                    title: "Most Improved",
                    values: summary.mostImprovedAthletes
                )
            }
            if !summary.teamAverages.isEmpty {
                testingListCard(
                    title: "Team Averages",
                    values: summary.teamAverages.sorted {
                        $0.key < $1.key
                    }.map { "\($0.key): \($0.value.formatted())" }
                )
            }
        }
    }

    private var athleteOverview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Performance")
                .font(AppTypography.title)
                .accessibilityAddTraits(.isHeader)

            if let latest = viewModel.analytics.first {
                TestingTrendCard(analytics: latest)
            }

            if !viewModel.personalRecords.isEmpty {
                testingListCard(
                    title: "Personal Records",
                    values: viewModel.personalRecords.map {
                        "\($0.metricName): \($0.careerBest.formatted()) \($0.unit)"
                    }
                )
            }
        }
    }

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Protocols")
                .font(AppTypography.title)
                .accessibilityAddTraits(.isHeader)

            if viewModel.protocols.isEmpty {
                Text("No testing protocols yet.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(viewModel.protocols) { value in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(value.name)
                                    .font(AppTypography.headline)
                                Text(
                                    "Version \(value.version) • \(value.metrics.count) metrics"
                                )
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            Text(value.status.rawValue.capitalized)
                                .font(AppTypography.caption)
                        }

                        HStack {
                            Button("Edit") { editorProtocol = value }
                            Button("Duplicate") {
                                Task { await viewModel.duplicate(value) }
                            }
                            Button("Schedule") {
                                schedulingProtocol = value
                            }
                            .disabled(value.status != .active)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                    )
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Upcoming Tests")
                .font(AppTypography.title)
                .accessibilityAddTraits(.isHeader)

            if viewModel.upcomingSessions.isEmpty {
                Text("No upcoming tests.")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(viewModel.upcomingSessions) { session in
                    NavigationLink {
                        TestingSessionEntryView(
                            session: session,
                            role: viewModel.role,
                            viewModel: viewModel
                        )
                    } label: {
                        testingSessionRow(session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var historySection: some View {
        NavigationLink {
            AthleteTestingHistoryView(
                sessions: viewModel.completedSessions
            )
        } label: {
            Label("Performance History", systemImage: "chart.xyaxis.line")
                .font(AppTypography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows historical testing results and trends")
    }

    private func testingSessionRow(
        _ session: TestingSession
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(session.protocolName)
                    .font(AppTypography.headline)
                Text(session.athleteName)
                    .font(AppTypography.body)
                Text(session.scheduledAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                ))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
    }

    private func testingCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(value)
                .font(AppTypography.largeTitle)
                .fontWeight(.bold)
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
    }

    private func testingListCard(
        title: String,
        values: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title).font(AppTypography.headline)
            ForEach(values, id: \.self) {
                Text($0).font(AppTypography.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}

private struct TestingTrendCard: View {
    let analytics: TestingMetricAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(analytics.metricName)
                .font(AppTypography.headline)
            Text("\(analytics.latest.formatted()) \(analytics.unit)")
                .font(AppTypography.title)
            Chart(analytics.history) {
                LineMark(
                    x: .value("Date", $0.date),
                    y: .value("Result", $0.value)
                )
                PointMark(
                    x: .value("Date", $0.date),
                    y: .value("Result", $0.value)
                )
            }
            .frame(height: 140)
            .accessibilityLabel("\(analytics.metricName) trend graph")
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}

private struct TestingSessionEntryView: View {
    let session: TestingSession
    let role: TestingViewerRole
    @ObservedObject var viewModel: TestingDashboardViewModel
    @State private var values: [UUID: String] = [:]
    @State private var notes: [UUID: String] = [:]

    var body: some View {
        Form {
            Section("Test") {
                Text(session.protocolName)
                Text(session.athleteName)
                Text(session.seasonLabel)
            }

            ForEach(session.metrics) { metric in
                Section(metric.name) {
                    if let existing = session.results.first(
                        where: { $0.metricID == metric.id }
                    ) {
                        Text(
                            "Previous: \(existing.value.formatted()) \(metric.unit)"
                        )
                    }
                    TextField(
                        "Result (\(metric.unit))",
                        text: Binding(
                            get: { values[metric.id, default: ""] },
                            set: { values[metric.id] = $0 }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .accessibilityLabel(
                        "\(metric.name) result in \(metric.unit)"
                    )
                    TextField(
                        "Notes",
                        text: Binding(
                            get: { notes[metric.id, default: ""] },
                            set: { notes[metric.id] = $0 }
                        )
                    )
                    Button("Save Result") {
                        guard let value = Double(
                            values[metric.id, default: ""]
                        ) else { return }
                        Task {
                            await viewModel.record(
                                session: session,
                                metric: metric,
                                value: value,
                                notes: notes[metric.id, default: ""]
                            )
                        }
                    }
                    .disabled(
                        role == .athlete && !session.allowsAthleteEntry
                    )
                }
            }

            Button("Complete Test") {
                Task { await viewModel.complete(session) }
            }
            .disabled(session.status == .completed)
        }
        .navigationTitle("Record Results")
    }
}

private struct TestingScheduleView: View {
    let protocolValue: TestingProtocol
    let athletes: [Athlete]
    let onSchedule: ([UUID], Date, String, String) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var date = Date()
    @State private var season = ""
    @State private var location = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Testing Date",
                    selection: $date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                TextField("Season", text: $season)
                TextField("Location", text: $location)
                Section("Athletes") {
                    ForEach(athletes, id: \.id) { athlete in
                        Button {
                            if selected.contains(athlete.id) {
                                selected.remove(athlete.id)
                            } else {
                                selected.insert(athlete.id)
                            }
                        } label: {
                            HStack {
                                Text(
                                    "\(athlete.firstName) \(athlete.lastName)"
                                )
                                Spacer()
                                if selected.contains(athlete.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .accessibilityValue(
                            selected.contains(athlete.id)
                                ? "Selected"
                                : "Not selected"
                        )
                    }
                }
            }
            .navigationTitle("Schedule \(protocolValue.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        Task {
                            await onSchedule(
                                Array(selected),
                                date,
                                season,
                                location
                            )
                        }
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}

extension TestingDashboardViewModel {
    var repositoryForEditor: TestingRepository {
        repository
    }
}
