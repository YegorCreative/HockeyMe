import SwiftUI

struct CoachSettingsView: View {
    @EnvironmentObject private var store: CoachAppStore

    var body: some View {
        Form {
            Section("Application") {
                LabeledContent("Role", value: store.isCoachSession ? "Coach" : "Unavailable")
                LabeledContent("Environment", value: MacBuildEnvironment.current.title)
#if DEBUG
                LabeledContent("Data Source", value: store.isInMemory ? "In-memory" : "Configured backend")
#endif
            }
            Section("Privacy") {
                Text("Forge Coach does not log credentials, session tokens, or athlete health details.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
