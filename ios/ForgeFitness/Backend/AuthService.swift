import Supabase

enum AccountCreationResult {
    case authenticated
    case emailConfirmationRequired
}

final class AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func createAccount(
        email: String,
        password: String
    ) async throws -> AccountCreationResult {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )

        return response.session == nil
            ? .emailConfirmationRequired
            : .authenticated
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func restoreSession() async -> Bool {
        do {
            _ = try await client.auth.session
            return true
        } catch {
            return false
        }
    }

    var authenticationChanges: AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session != nil)
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
