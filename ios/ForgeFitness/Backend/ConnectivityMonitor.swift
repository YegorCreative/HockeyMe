import Foundation
import Network

final class ConnectivityMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(
        label: "com.forgefitness.connectivity",
        qos: .utility
    )
    private var wasConnected = false

    func start(onConnected: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let isConnected = path.status == .satisfied
            defer { wasConnected = isConnected }
            guard isConnected, !wasConnected else { return }
            onConnected()
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
