import Foundation
import MetricKit

final class DiagnosticsService: NSObject, MXMetricManagerSubscriber,
    @unchecked Sendable {
    static let shared = DiagnosticsService()

    private let logger = LoggingService.shared
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
        logger.log(
            "diagnostics_started",
            category: .application,
            metadata: LogMetadata([
                "environment": AppEnvironment.build.rawValue
            ])
        )
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        logger.log(
            "metrickit_payload_received",
            category: .performance,
            metadata: LogMetadata(["payload_count": "\(payloads.count)"])
        )
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        logger.log(
            "crash_diagnostic_received",
            category: .errors,
            level: .error,
            metadata: LogMetadata(["payload_count": "\(payloads.count)"])
        )
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }
}
