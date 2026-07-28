import Combine

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    private let authService: AuthService?

    init(
        authService: AuthService?,
        initialErrorMessage: String? = nil
    ) {
        self.authService = authService
        errorMessage = initialErrorMessage
    }

    func signIn() async {
        guard validateFields() else {
            return
        }

        guard let authService else {
            errorMessage = "Authentication is temporarily unavailable. Please try again later."
            return
        }

        beginRequest()

        do {
            try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        } catch {
            errorMessage = "We couldn't sign you in. Check your email and password, then try again."
        }

        isLoading = false
    }

    func createAccount() async {
        guard validateFields() else {
            return
        }

        guard let authService else {
            errorMessage = "Account creation is temporarily unavailable. Please try again later."
            return
        }

        beginRequest()

        do {
            let result = try await authService.createAccount(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            if case .emailConfirmationRequired = result {
                statusMessage = "Check your email to confirm your account, then sign in."
            }
        } catch {
            errorMessage = "We couldn't create your account. Check your details and try again."
        }

        isLoading = false
    }

    private func validateFields() -> Bool {
        errorMessage = nil
        statusMessage = nil

        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "Enter your email and password to continue."
            return false
        }

        return true
    }

    private func beginRequest() {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
    }
}
