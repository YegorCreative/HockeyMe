import Foundation

enum AnalyticsEvent: String, CaseIterable, Sendable {
    case authenticationSignInSucceeded = "authentication_sign_in_succeeded"
    case authenticationSignInFailed = "authentication_sign_in_failed"
    case authenticationAccountCreated = "authentication_account_created"
    case workoutStarted = "workout_started"
    case workoutSetCompleted = "workout_set_completed"
    case workoutCompleted = "workout_completed"
    case testingOpened = "testing_opened"
    case testingResultRecorded = "testing_result_recorded"
    case programCreated = "program_created"
    case programPublished = "program_published"
    case organizationSelected = "organization_selected"
    case organizationCreated = "organization_created"
    case invitationSent = "invitation_sent"
    case invitationFailed = "invitation_failed"
    case invitationAccepted = "invitation_accepted"
    case offlineSyncStarted = "offline_sync_started"
    case offlineSyncCompleted = "offline_sync_completed"
    case offlineSyncFailed = "offline_sync_failed"
    case operationalError = "operational_error"

    var category: LogCategory {
        switch self {
        case .authenticationSignInSucceeded,
             .authenticationSignInFailed,
             .authenticationAccountCreated:
            .authentication
        case .workoutStarted, .workoutSetCompleted, .workoutCompleted:
            .workout
        case .testingOpened, .testingResultRecorded:
            .testing
        case .programCreated, .programPublished:
            .programs
        case .organizationSelected, .organizationCreated:
            .organizations
        case .invitationSent, .invitationFailed, .invitationAccepted:
            .invitations
        case .offlineSyncStarted, .offlineSyncCompleted, .offlineSyncFailed:
            .offlineSync
        case .operationalError:
            .errors
        }
    }
}

actor AnalyticsService {
    static let shared = AnalyticsService()

    private let defaults: UserDefaults
    private let logger: LoggingService
    private let enabledKey = "analytics_enabled"

    init(
        defaults: UserDefaults = .standard,
        logger: LoggingService = .shared
    ) {
        self.defaults = defaults
        self.logger = logger
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }
    }

    var isEnabled: Bool {
        defaults.bool(forKey: enabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: enabledKey)
        logger.log(
            enabled ? "analytics_enabled" : "analytics_disabled",
            category: .application,
            level: .notice
        )
    }

    func track(
        _ event: AnalyticsEvent,
        metadata: LogMetadata = LogMetadata()
    ) {
        guard isEnabled else { return }
        logger.log(
            event.rawValue,
            category: event.category,
            level: .info,
            metadata: metadata
        )
    }
}
