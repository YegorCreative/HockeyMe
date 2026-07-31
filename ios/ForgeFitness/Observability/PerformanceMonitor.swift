import Foundation

struct PerformanceMonitor: Sendable {
    static let shared = PerformanceMonitor()

    private let logger = LoggingService.shared

    func measure<T: Sendable>(
        _ operation: String,
        category: LogCategory = .performance,
        work: @Sendable () async throws -> T
    ) async rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let result = try await work()
            let duration = start.duration(to: clock.now)
            logger.log(
                operation,
                category: category,
                metadata: LogMetadata([
                    "result": "success",
                    "duration_ms": Self.milliseconds(duration)
                ])
            )
            return result
        } catch {
            let duration = start.duration(to: clock.now)
            logger.log(
                operation,
                category: category,
                level: .error,
                metadata: LogMetadata([
                    "result": "failure",
                    "duration_ms": Self.milliseconds(duration),
                    "error_type": String(describing: type(of: error))
                ])
            )
            throw error
        }
    }

    private static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        let milliseconds = components.seconds * 1_000
            + components.attoseconds / 1_000_000_000_000_000
        return String(milliseconds)
    }
}
