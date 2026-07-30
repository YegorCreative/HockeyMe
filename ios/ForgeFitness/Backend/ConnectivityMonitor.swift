import Foundation
import Network

final class ConnectivityMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(
        label: "com.forgefitness.connectivity",
        qos: .utility
    )

    func start(onConnected: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            onConnected()
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
