// xcode: set sdk=iOS

import SwiftUI

@main
struct ForgeFitnessApp: App {
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            switch router.route {
            case .authentication:
                AuthenticationView()
            case .athleteHome:
                AthleteHomeView()
            case .coachHome:
                CoachHomeView()
            case .loading:
                LoadingView()
            }
        }
    }
}
