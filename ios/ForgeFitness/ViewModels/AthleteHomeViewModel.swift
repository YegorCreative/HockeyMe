import Combine

@MainActor
final class AthleteHomeViewModel: ObservableObject {
    @Published private(set) var isSigningOut = false
    @Published private(set) var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func signOut() async {
        isSigningOut = true
        errorMessage = nil

        do {
            try await authService.signOut()
        } catch {
            errorMessage = "We couldn't sign you out. Please try again."
        }

        isSigningOut = false
    }
}
