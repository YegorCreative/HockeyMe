import SwiftUI

struct OrganizationWorkspaceView: View {
    @EnvironmentObject private var store: CoachAppStore
    @State private var tab = OrganizationTab.members
    @State private var memberSelection = Set<UUID>()
    @State private var invitationSelection = Set<UUID>()
    @State private var showTransferConfirmation = false

    enum OrganizationTab: String, CaseIterable, Identifiable {
        case members, seasons, invitations
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading) {
                    Text(store.organizations.first?.name ?? "Organization")
                        .font(AppTypography.title2.bold())
                    Text("Organization administration")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Section", selection: $tab) {
                    ForEach(OrganizationTab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }
            .padding([.horizontal, .top])

            switch tab {
            case .members: members
            case .seasons: seasons
            case .invitations: invitations
            }
        }
        .navigationTitle("Organization")
        .toolbar {
            Button("Transfer Ownership") {
                showTransferConfirmation = true
            }
            .disabled(memberSelection.count != 1)
        }
        .confirmationDialog(
            "Transfer organization ownership?",
            isPresented: $showTransferConfirmation
        ) {
            Button("Transfer Ownership", role: .destructive) {}
        } message: {
            Text("This production-backed action requires explicit repository authorization.")
        }
    }

    private var members: some View {
        Table(store.members, selection: $memberSelection) {
            TableColumn("Name") { Text($0.displayName).fontWeight(.medium) }
            TableColumn("Email") { Text($0.email) }
            TableColumn("Roles") {
                Text($0.roles.map(\.title).joined(separator: ", "))
            }
            TableColumn("Status") {
                MacStatusBadge(text: $0.status.capitalized, color: AppColors.success)
            }
        }
        .contextMenu(forSelectionType: UUID.self) { _ in
            Button("Review Roles") {}
        }
    }

    private var seasons: some View {
        Table(store.seasons) {
            TableColumn("Season") { Text($0.name).fontWeight(.medium) }
            TableColumn("Starts") { Text($0.startsOn, format: .dateTime.month().day().year()) }
            TableColumn("Ends") { Text($0.endsOn, format: .dateTime.month().day().year()) }
            TableColumn("Status") {
                MacStatusBadge(
                    text: $0.isArchived ? "Archived" : "Active",
                    color: $0.isArchived ? AppColors.textSecondary : AppColors.success
                )
            }
        }
    }

    private var invitations: some View {
        Table(store.invitations, selection: $invitationSelection) {
            TableColumn("Email") { Text($0.email) }
            TableColumn("Roles") { Text($0.roles.map(\.title).joined(separator: ", ")) }
            TableColumn("Expires") { Text($0.expiresAt, format: .dateTime.month().day().year()) }
            TableColumn("Status") { MacStatusBadge(text: $0.status.capitalized) }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button("Revoke Invitation", role: .destructive) {
                store.invitations.removeAll { ids.contains($0.id) }
            }
        }
    }
}
