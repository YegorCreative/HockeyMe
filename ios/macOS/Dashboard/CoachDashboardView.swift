import SwiftUI

struct CoachDashboardView: View {
    @EnvironmentObject private var store: CoachAppStore

    private let columns = [
        GridItem(.adaptive(minimum: 190), spacing: AppSpacing.md)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                MacSectionHeader(
                    title: "Dashboard",
                    subtitle: store.dashboard.organizationName
                )

                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    MacMetricCard(
                        title: "Active Teams",
                        value: "\(store.dashboard.activeTeams)",
                        symbol: "person.3"
                    )
                    MacMetricCard(
                        title: "Athletes",
                        value: "\(store.dashboard.athleteCount)",
                        symbol: "figure.hockey"
                    )
                    MacMetricCard(
                        title: "Current Programs",
                        value: "\(store.dashboard.currentPrograms)",
                        symbol: "calendar.badge.clock"
                    )
                    MacMetricCard(
                        title: "Program Workouts",
                        value: "\(store.dashboard.upcomingWorkouts)",
                        symbol: "dumbbell"
                    )
                    MacMetricCard(
                        title: "Recent Tests",
                        value: "\(store.dashboard.recentTests)",
                        symbol: "gauge.with.dots.needle.67percent"
                    )
                    MacMetricCard(
                        title: "Assigned Athletes",
                        value: "\(store.dashboard.assignedAthletes)",
                        symbol: "checkmark.circle"
                    )
                }

                GroupBox("Quick Actions") {
                    HStack {
                        Button("New Program") {
                            store.navigate(to: .programming)
                            store.createPrimaryObject()
                        }
                        Button("Athlete List") { store.navigate(to: .athletes) }
                        Button("Testing") { store.navigate(to: .testing) }
                        Button("Organization") { store.navigate(to: .organization) }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)
                }
            }
            .padding(AppSpacing.lg)
        }
        .navigationTitle("Dashboard")
    }
}
