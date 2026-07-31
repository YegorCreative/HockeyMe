import Foundation
import Supabase

enum AuthenticationServiceError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case emailConfirmationRequired
    case networkUnavailable
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "The email or password is incorrect."
        case .emailAlreadyExists:
            "An account already exists for this email."
        case .emailConfirmationRequired:
            "Confirm your email before signing in."
        case .networkUnavailable:
            "A network connection isn't available. Check your connection and try again."
        case .unknown:
            "Something went wrong. Please try again."
        }
    }
}

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
        do {
            try await client.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            log(error, operation: "signIn")
            throw mappedError(from: error)
        }
    }

    func createAccount(
        email: String,
        password: String
    ) async throws -> AccountCreationResult {
        let response: AuthResponse

        do {
            response = try await client.auth.signUp(
                email: email,
                password: password
            )
        } catch {
            log(error, operation: "signUp")
            throw mappedError(from: error)
        }

        return response.session == nil
            ? .emailConfirmationRequired
            : .authenticated
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            log(error, operation: "signOut")
            throw mappedError(from: error)
        }
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

    private func mappedError(from error: Error) -> AuthenticationServiceError {
        if isNetworkError(error) {
            return .networkUnavailable
        }

        guard let authError = error as? AuthError else {
            return .unknown
        }

        switch authError.errorCode {
        case .invalidCredentials:
            return .invalidCredentials
        case .emailExists, .userAlreadyExists:
            return .emailAlreadyExists
        case .emailNotConfirmed:
            return .emailConfirmationRequired
        case .requestTimeout:
            return .networkUnavailable
        default:
            return .unknown
        }
    }

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            return true
        }

        if let underlyingError = nsError.userInfo[
            NSUnderlyingErrorKey
        ] as? Error {
            return isNetworkError(underlyingError)
        }

        return false
    }

    private func log(_ error: Error, operation: String) {
        var metadata = [
            "operation": operation,
            "error_type": String(describing: type(of: error))
        ]
        if let authError = error as? AuthError {
            metadata["error_code"] = authError.errorCode.rawValue
        } else {
            let nsError = error as NSError
            metadata["error_domain"] = nsError.domain
            metadata["error_code"] = "\(nsError.code)"
        }
        LoggingService.shared.log(
            "authentication_request_failed",
            category: .authentication,
            level: .error,
            metadata: LogMetadata(metadata)
        )
    }
}
