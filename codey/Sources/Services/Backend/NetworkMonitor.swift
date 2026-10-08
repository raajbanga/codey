import Foundation
import Network
import Observation

/// NWPathMonitor-backed Reachability. Publishes on the main actor.
@MainActor
@Observable
final class NetworkMonitor: Reachability {
    private(set) var isReachable = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            Task { @MainActor in self?.update(reachable) }
        }
        monitor.start(queue: DispatchQueue(label: "edu.wku.cs360.codey.network-monitor"))
    }

    deinit {
        monitor.cancel()
    }

    func changes() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    private func update(_ reachable: Bool) {
        guard reachable != isReachable else { return }
        isReachable = reachable
        for continuation in continuations.values {
            continuation.yield(reachable)
        }
    }
}
