import Foundation

enum AppErrorKind: Equatable {
    case network
    case authentication
    case validation
    case permission
    case missingData
    case timeout
    case cancellation
    case repository
    case unexpected
}

struct AppErrorPresentation: Equatable {
    let kind: AppErrorKind
    let title: String
    let message: String
    let recoveryAction: String?
    let canRetry: Bool

    static func make(for error: Error) -> AppErrorPresentation {
        if error is CancellationError {
            return AppErrorPresentation(
                kind: .cancellation,
                title: "Request Cancelled",
                message: "The operation was cancelled.",
                recoveryAction: nil,
                canRetry: false
            )
        }

        if let authenticationError = error as? AuthenticationServiceError {
            return authentication(authenticationError)
        }

        if let serviceError = error as? AthleteServiceError {
            switch serviceError {
            case .profileNotFound:
                return missingData("Your athlete profile could not be found.")
            case .invalidProfile:
                return validation("The athlete profile contains invalid data.")
            case .unauthorized:
                return permission()
            }
        }

        if let repositoryError = error as? TrainingRepositoryError {
            switch repositoryError {
            case .athleteProfileMissing, .activeAssignmentMissing:
                return missingData(repositoryError.localizedDescription)
            case .invalidTrainingData, .sessionUnavailable:
                return repository(repositoryError.localizedDescription)
            }
        }

        if error is ProgramRepositoryError ||
            error is TestingRepositoryError ||
            error is OrganizationRepositoryError {
            return repository(error.localizedDescription)
        }

        let nsError = error as NSError
        if isNetworkError(nsError) {
            if nsError.code == NSURLErrorTimedOut {
                return AppErrorPresentation(
                    kind: .timeout,
                    title: "Request Timed Out",
                    message: "The server took too long to respond.",
                    recoveryAction: "Check your connection and try again.",
                    canRetry: true
                )
            }
            return AppErrorPresentation(
                kind: .network,
                title: "You're Offline",
                message: "A network connection isn't available.",
                recoveryAction: "Reconnect and try again.",
                canRetry: true
            )
        }

        return AppErrorPresentation(
            kind: .unexpected,
            title: "Something Went Wrong",
            message: "Forge Fitness couldn't complete this request.",
            recoveryAction: "Try again. If the problem continues, contact support.",
            canRetry: true
        )
    }

    var combinedMessage: String {
        guard let recoveryAction else { return message }
        return "\(message) \(recoveryAction)"
    }

    private static func authentication(
        _ error: AuthenticationServiceError
    ) -> AppErrorPresentation {
        AppErrorPresentation(
            kind: error == .networkUnavailable ? .network : .authentication,
            title: "Authentication Unavailable",
            message: error.localizedDescription,
            recoveryAction: error == .networkUnavailable
                ? "Check your connection and try again."
                : nil,
            canRetry: error == .networkUnavailable
        )
    }

    private static func permission() -> AppErrorPresentation {
        AppErrorPresentation(
            kind: .permission,
            title: "Permission Required",
            message: "You don't have permission to perform this action.",
            recoveryAction: "Ask an organization administrator for access.",
            canRetry: false
        )
    }

    private static func validation(_ message: String) -> AppErrorPresentation {
        AppErrorPresentation(
            kind: .validation,
            title: "Check Your Information",
            message: message,
            recoveryAction: "Correct the highlighted information and try again.",
            canRetry: false
        )
    }

    private static func missingData(_ message: String) -> AppErrorPresentation {
        AppErrorPresentation(
            kind: .missingData,
            title: "Not Available",
            message: message,
            recoveryAction: nil,
            canRetry: false
        )
    }

    private static func repository(_ message: String) -> AppErrorPresentation {
        AppErrorPresentation(
            kind: .repository,
            title: "Data Unavailable",
            message: message,
            recoveryAction: "Try again.",
            canRetry: true
        )
    }

    private static func isNetworkError(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain {
            return true
        }
        guard let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
        else {
            return false
        }
        return isNetworkError(underlying)
    }
}
