import Foundation

actor SynchronizationGate {
    private var activeTask: Task<Void, Error>?

    func run(
        operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        if let activeTask {
            return try await activeTask.value
        }

        let task = Task {
            try await operation()
        }
        activeTask = task
        defer { activeTask = nil }
        try await task.value
    }
}
