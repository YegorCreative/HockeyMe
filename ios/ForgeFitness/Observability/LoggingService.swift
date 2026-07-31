import Foundation
import OSLog

enum LogCategory: String, CaseIterable {
    case application
    case authentication
    case network
    case workout
    case testing
    case programs
    case organizations
    case invitations
    case offlineSync
    case performance
    case errors
}

enum LogLevel {
    case debug
    case info
    case notice
    case warning
    case error
    case fault
}

struct LogMetadata: Sendable {
    private let values: [String: String]

    init(_ values: [String: String] = [:]) {
        self.values = values.reduce(into: [:]) { result, item in
            let key = item.key
                .lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            guard !key.isEmpty,
                  !Self.sensitiveKeys.contains(where: key.contains) else {
                return
            }
            result[key] = String(item.value.prefix(120))
        }
    }

    var redactedDescription: String {
        values.keys.sorted().map { "\($0)=<private>" }.joined(separator: " ")
    }

    private static let sensitiveKeys = [
        "email", "password", "token", "secret", "key", "authorization",
        "name", "note", "message", "url", "body"
    ]
}

final class LoggingService: Sendable {
    static let shared = LoggingService()

    private let subsystem: String

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "ForgeFitness") {
        self.subsystem = subsystem
    }

    func log(
        _ event: String,
        category: LogCategory,
        level: LogLevel = .info,
        metadata: LogMetadata = LogMetadata()
    ) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        let safeEvent = Self.safeEvent(event)
        let context = metadata.redactedDescription

        switch level {
        case .debug:
            logger.debug(
                "\(safeEvent, privacy: .public) \(context, privacy: .private)"
            )
        case .info:
            logger.info(
                "\(safeEvent, privacy: .public) \(context, privacy: .private)"
            )
        case .notice:
            logger.notice(
                "\(safeEvent, privacy: .public) \(context, privacy: .private)"
            )
        case .warning:
            logger.warning(
                "\(safeEvent, privacy: .public) \(context, privacy: .private)"
            )
        case .error:
            logger.error(
                "\(safeEvent, privacy: .public) \(context, privacy: .private)"
            )
        case .fault:
            logger.fault(
                "\(safeEvent, privacy: .public) \(context, privacy: .private)"
            )
        }
    }

    private static func safeEvent(_ value: String) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber || character == "_"
                    ? character
                    : "_"
            }
        return String(normalized.prefix(80))
    }
}
