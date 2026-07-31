import Foundation

struct NetworkDiagnostics: Sendable {
    static let shared = NetworkDiagnostics()

    func record(
        operation: String,
        statusCode: Int?,
        duration: Duration,
        wasConnected: Bool
    ) {
        LoggingService.shared.log(
            operation,
            category: .network,
            level: statusCode.map { 200..<400 ~= $0 } == false
                ? .warning
                : .info,
            metadata: LogMetadata([
                "status_class": statusCode.map { "\($0 / 100)xx" } ?? "none",
                "duration_ms": Self.milliseconds(duration),
                "connected": wasConnected ? "true" : "false",
                "environment": AppEnvironment.build.rawValue
            ])
        )
    }

    private static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        return String(
            components.seconds * 1_000
                + components.attoseconds / 1_000_000_000_000_000
        )
    }
}
