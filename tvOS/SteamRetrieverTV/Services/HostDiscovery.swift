// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// Bonjour: finds Steam Retriever (_steamretriever._tcp) and Sunshine (_nvstream._tcp) on the LAN.

import Foundation
import Network
import Observation

@MainActor
@Observable
final class HostDiscovery {
    struct Found: Identifiable, Hashable {
        let name: String
        let endpoint: NWEndpoint
        var id: String { name }
    }

    private(set) var macs: [Found] = []
    private(set) var sunshineHosts: [String] = []
    private(set) var browsing = false

    @ObservationIgnored private var browsers: [NWBrowser] = []

    func start() {
        guard browsers.isEmpty else { return }
        browsing = true
        browsers = [
            browse("_steamretriever._tcp") { [weak self] found in self?.macs = found },
            browse("_nvstream._tcp") { [weak self] found in self?.sunshineHosts = found.map(\.name) },
        ]
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers = []
        browsing = false
    }

    private func browse(_ type: String, update: @escaping @MainActor ([Found]) -> Void) -> NWBrowser {
        let b = NWBrowser(for: .bonjour(type: type, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { results, _ in
            let found: [Found] = results.compactMap { r in
                if case let .service(name, _, _, _) = r.endpoint { return Found(name: name, endpoint: r.endpoint) }
                return nil
            }.sorted { $0.name < $1.name }
            Task { @MainActor in update(found) }
        }
        b.start(queue: .main)
        return b
    }

    /// Resolves a Bonjour service to "ip:port" (IPv4, so it drops straight into a URL).
    static func resolve(_ endpoint: NWEndpoint, timeout: TimeInterval = 4) async -> String? {
        let params = NWParameters.tcp
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let conn = NWConnection(to: endpoint, using: params)
        let once = ResumeOnce()
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var result: String?
                    if case let .hostPort(host, port) = conn.currentPath?.remoteEndpoint {
                        let h = "\(host)".split(separator: "%").first.map(String.init) ?? "\(host)"
                        result = "\(h):\(port.rawValue)"
                    }
                    conn.cancel()
                    if once.claim() { cont.resume(returning: result) }
                case .failed:
                    conn.cancel()
                    if once.claim() { cont.resume(returning: nil) }
                case .cancelled:
                    conn.stateUpdateHandler = nil   // break the conn <-> handler cycle
                    if once.claim() { cont.resume(returning: nil) }
                default:
                    break
                }
            }
            conn.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                conn.cancel()
                if once.claim() { cont.resume(returning: nil) }
            }
        }
    }
}

/// Guards a continuation against being resumed twice (ready vs timeout races).
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
