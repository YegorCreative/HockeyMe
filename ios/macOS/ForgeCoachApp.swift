import SwiftUI

@main
struct ForgeCoachApp: App {
    @StateObject private var store = CoachAppBootstrap.makeStore()

    var body: some Scene {
        WindowGroup("Forge Fitness Coach") {
            Group {
                if case let .unavailable(message) = store.bootstrapState {
                    MacErrorView(message: message)
                } else if store.isCoachSession {
                    CoachShellView()
                        .environmentObject(store)
                } else {
                    MacEmptyDetailView(
                        title: "Coach Authentication Required",
                        message: "Sign in with an authorized coach account.",
                        symbol: "person.badge.key"
                    )
                }
            }
            .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1_280, height: 820)
        .commands {
            ForgeCoachCommands(store: store)
        }
    }
}

struct ForgeCoachCommands: Commands {
    @ObservedObject var store: CoachAppStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New \(store.selection.title)") {
                store.createPrimaryObject()
            }
            .keyboardShortcut("n")
            .disabled(![.programming, .testing, .teams].contains(store.selection))
        }
        CommandGroup(after: .saveItem) {
            Button("Save") { store.save() }
                .keyboardShortcut("s")
        }
        CommandMenu("Navigate") {
            ForEach(CoachSection.allCases) { section in
                Button(section.title) { store.navigate(to: section) }
                    .keyboardShortcut(section.shortcut, modifiers: .command)
            }
        }
        CommandMenu("Coach") {
            Button("Find") { store.focusSearch() }
                .keyboardShortcut("f")
            Button("Duplicate Program") { store.duplicateSelectedProgram() }
                .keyboardShortcut("d")
                .disabled(store.selection != .programming || store.selectedProgram == nil)
        }
    }
}
