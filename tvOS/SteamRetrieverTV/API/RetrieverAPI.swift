// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// Client for the Steam Retriever HTTP API on the Mac (port 48080, plain HTTP on the LAN).

import Foundation

enum APIError: LocalizedError, Equatable {
    case badAddress(String)
    case unreachable(String)
    case timedOut
    case notSteamRetriever
    case unauthorized
    case pairing(String)
    case conflict(String)
    case notFound(String)
    case server(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badAddress(let a): return "\"\(a)\" isn't a valid address. Try mini.local or an IP like 192.168.1.20."
        case .unreachable(let why): return "Can't reach the Mac (\(why)). Is it awake and on the same network?"
        case .timedOut: return "The Mac didn't answer in time. Is Steam Retriever running on it?"
        case .notSteamRetriever: return "Something answered, but it isn't Steam Retriever."
        case .unauthorized: return "This Apple TV isn't paired with Steam Retriever anymore. Pair it again."
        case .pairing(let msg): return msg.prefix(1).uppercased() + msg.dropFirst() + "."
        case .conflict(let msg): return msg
        case .notFound(let what): return "Not found: \(what)."
        case .server(let code, let msg): return "The Mac returned an error (\(code)): \(msg)"
        case .decoding(let what): return "Unexpected reply from the Mac (\(what))."
        }
    }
}

struct RetrieverAPI {
    static let defaultPort = 48080
    static let pingTimeout: TimeInterval = 2
    static let callTimeout: TimeInterval = 8

    let baseURL: URL
    var token: String?
    var session: URLSession = .shared

    init(baseURL: URL, token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    /// "mini.local", "192.168.1.20", "mini.local:48080" or a full http URL -> http://host:48080
    static func baseURL(for address: String) -> URL? {
        var a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty else { return nil }
        if !a.contains("://") { a = "http://" + a }
        guard var c = URLComponents(string: a), let host = c.host, !host.isEmpty else { return nil }
        if c.port == nil { c.port = defaultPort }
        c.path = ""
        c.query = nil
        return c.url
    }

    // MARK: endpoints

    func ping() async throws -> PingResponse {
        let p: PingResponse = try await json(get("api/ping", timeout: Self.pingTimeout))
        guard p.app == "Steam Retriever" else { throw APIError.notSteamRetriever }
        return p
    }

    func pair(code: String, deviceName: String) async throws -> String {
        var r = request("api/pair", method: "POST")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["code": code, "name": deviceName])
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Paired: Decodable { var token: String }
        let p: Paired = try await json(r)
        return p.token
    }

    func games() async throws -> [Game] {
        try await json(get("api/games"))
    }

    func status() async throws -> ServerStatus {
        try await json(get("api/status"))
    }

    func launch(_ id: String) async throws -> LaunchState {
        struct Launched: Decodable { var ok: Bool; var state: String? }
        let l: Launched = try await json(request("api/launch/\(escape(id))", method: "POST"))
        return LaunchState(rawValue: l.state ?? "") ?? .starting
    }

    /// Image URLs carry the token as a query item so AsyncImage and URLCache can use them directly.
    func coverURL(_ id: String, kind: CoverKind = .poster) -> URL? {
        guard var c = URLComponents(url: url("api/games/\(escape(id))/cover"), resolvingAgainstBaseURL: false) else { return nil }
        var items = [URLQueryItem(name: "kind", value: kind.rawValue)]
        if let token { items.append(URLQueryItem(name: "token", value: token)) }
        c.queryItems = items
        return c.url
    }

    // MARK: plumbing

    private func escape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    private func url(_ path: String) -> URL {
        URL(string: path, relativeTo: baseURL)?.absoluteURL ?? baseURL.appendingPathComponent(path)
    }

    private func request(_ path: String, method: String, timeout: TimeInterval = callTimeout) -> URLRequest {
        var r = URLRequest(url: url(path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        r.httpMethod = method
        if let token { r.setValue(token, forHTTPHeaderField: "X-Retriever-Token") }
        return r
    }

    private func get(_ path: String, timeout: TimeInterval = callTimeout) -> URLRequest {
        request(path, method: "GET", timeout: timeout)
    }

    private func json<T: Decodable>(_ r: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: r)
        } catch let e as URLError {
            switch e.code {
            case .timedOut: throw APIError.timedOut
            case .cancelled: throw CancellationError()
            default: throw APIError.unreachable(e.localizedDescription)
            }
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.decoding("not HTTP") }
        // Errors look like {"error": "..."}; a failed launch is {"ok": false, "error": "Finish <game> first."}
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = body?["error"] as? String ?? ""
        switch http.statusCode {
        case 200: break
        case 401: throw APIError.unauthorized
        case 403: throw APIError.pairing(message.isEmpty ? "pairing refused" : message)
        case 404: throw APIError.notFound(message.isEmpty ? (r.url?.path ?? "") : message)
        case 409: throw APIError.conflict(message.isEmpty ? "Another game is still running." : message)
        default: throw APIError.server(http.statusCode, message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: T.self))
        }
    }
}
