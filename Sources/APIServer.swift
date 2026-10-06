import Foundation
import Network
import AppKit

struct HTTPRequest {
    var method: String
    var path: String
    var query: [String: String]
    var headers: [String: String]
    var body: Data
}

struct HTTPResponse {
    var status: Int
    var contentType: String
    var body: Data
    var cache: String = "no-store"

    static func json(_ obj: Any, status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data("{}".utf8)
        return HTTPResponse(status: status, contentType: "application/json", body: data)
    }
}

/// A small local HTTP API so the Apple TV app can list games, fetch covers and start a game.
/// Port 48080, advertised over Bonjour as _steamretriever._tcp. Everything except /api/ping and /api/pair needs a token.
@MainActor
final class APIServer {
    static let port: UInt16 = 48080
    private unowned let lib: Library
    private var listener: NWListener?

    private var pairCode: String?
    private var pairExpiry = Date.distantPast
    private var pairFails = 0

    init(lib: Library) { self.lib = lib }

    // MARK: lifecycle
    func start() {
        guard listener == nil else { return }
        do {
            guard let port = NWEndpoint.Port(rawValue: Self.port) else { return }
            let l = try NWListener(using: .tcp, on: port)
            l.service = NWListener.Service(name: "Steam Retriever", type: "_steamretriever._tcp")
            l.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in self?.accept(conn) }
            }
            l.stateUpdateHandler = { state in Log.write("API listener: \(state)") }
            l.start(queue: .main)
            listener = l
        } catch {
            Log.write("API failed to start: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: pairing
    func beginPairing() -> String {
        let code = String(format: "%06d", Int.random(in: 0..<1_000_000))
        pairCode = code
        pairExpiry = Date().addingTimeInterval(300)
        pairFails = 0
        return code
    }

    func endPairing() { pairCode = nil }

    private static let tokenKey = "apiTokens"

    private func tokens() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: Self.tokenKey) as? [String: String]) ?? [:]
    }

    private func pair(_ r: HTTPRequest) -> HTTPResponse {
        guard let code = pairCode, Date() < pairExpiry, pairFails < 5 else {
            return .json(["error": "no pairing in progress; choose Pair Apple TV in Steam Retriever"], status: 403)
        }
        let obj = (try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any]
        guard let given = obj?["code"] as? String, given == code else {
            pairFails += 1
            if pairFails >= 5 { pairCode = nil }
            return .json(["error": "wrong code"], status: 403)
        }
        let token = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        var all = tokens()
        all[token] = (obj?["name"] as? String) ?? "Apple TV"
        UserDefaults.standard.set(all, forKey: Self.tokenKey)
        pairCode = nil
        lib.pairingDone()
        Log.write("API: paired \(all[token] ?? "device")")
        return .json(["token": token])
    }

    private func authorized(_ r: HTTPRequest) -> Bool {
        let t = r.headers["x-retriever-token"] ?? r.query["token"] ?? ""
        return !t.isEmpty && tokens()[t] != nil
    }

    // MARK: connections
    private func accept(_ conn: NWConnection) {
        conn.start(queue: .main)
        read(conn, buffer: Data())
    }

    private enum Parsed {
        case incomplete
        case bad
        case request(HTTPRequest)
    }

    private func read(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, err in
            Task { @MainActor in
                guard let self = self else { conn.cancel(); return }
                var buf = buffer
                if let d = data { buf.append(d) }
                if err != nil || (data == nil && done) { conn.cancel(); return }
                switch Self.parse(buf) {
                case .incomplete:
                    if buf.count > 65536 { conn.cancel() } else { self.read(conn, buffer: buf) }
                case .bad:
                    self.send(conn, .json(["error": "bad request"], status: 400))
                case .request(let req):
                    let resp = await self.route(req)
                    self.send(conn, resp)
                }
            }
        }
    }

    private static func parse(_ buf: Data) -> Parsed {
        guard let end = buf.range(of: Data("\r\n\r\n".utf8)) else { return .incomplete }
        let head = String(decoding: buf[buf.startIndex..<end.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        let first = lines.removeFirst().split(separator: " ")
        guard first.count >= 2 else { return .bad }
        var headers: [String: String] = [:]
        for l in lines {
            if let c = l.firstIndex(of: ":") {
                let key = l[..<c].lowercased()
                let val = l[l.index(after: c)...].trimmingCharacters(in: .whitespaces)
                headers[key] = val
            }
        }
        let len = Int(headers["content-length"] ?? "0") ?? 0
        if len < 0 || len > 16384 { return .bad }
        let bodyStart = end.upperBound
        if buf.endIndex - bodyStart < len { return .incomplete }
        let body = Data(buf[bodyStart..<(bodyStart + len)])
        guard let comps = URLComponents(string: "http://x" + String(first[1])) else { return .bad }
        var query: [String: String] = [:]
        for item in comps.queryItems ?? [] { query[item.name] = item.value ?? "" }
        return .request(HTTPRequest(method: String(first[0]).uppercased(), path: comps.path,
                                    query: query, headers: headers, body: body))
    }

    private func send(_ conn: NWConnection, _ r: HTTPResponse) {
        let names = [200: "OK", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 409: "Conflict"]
        let head = "HTTP/1.1 \(r.status) \(names[r.status] ?? "OK")\r\nContent-Type: \(r.contentType)\r\n"
            + "Content-Length: \(r.body.count)\r\nConnection: close\r\nCache-Control: \(r.cache)\r\n\r\n"
        var out = Data(head.utf8)
        out.append(r.body)
        conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
    }

    // MARK: routes
    private func route(_ r: HTTPRequest) async -> HTTPResponse {
        let parts = r.path.split(separator: "/").map(String.init)
        guard parts.first == "api" else { return .json(["error": "not found"], status: 404) }
        let seg = Array(parts.dropFirst())

        if r.method == "GET" && seg == ["ping"] { return .json(["app": "Steam Retriever", "api": 1]) }
        if r.method == "POST" && seg == ["pair"] { return pair(r) }
        guard authorized(r) else { return .json(["error": "unauthorized"], status: 401) }

        if r.method == "GET" && seg == ["games"] {
            return .json(lib.games.map { gameDict($0) })
        }
        if r.method == "GET" && seg == ["status"] {
            return .json(await statusDict())
        }
        if r.method == "GET" && seg.count == 3 && seg[0] == "games" && seg[2] == "cover" {
            guard let g = lib.games.first(where: { $0.id == seg[1] }) else { return .json(["error": "unknown game"], status: 404) }
            return await cover(g, kind: r.query["kind"] ?? "poster")
        }
        if r.method == "POST" && seg.count == 2 && seg[0] == "launch" {
            guard let g = lib.games.first(where: { $0.id == seg[1] }) else { return .json(["error": "unknown game"], status: 404) }
            let result = lib.startFromAPI(g)
            if result.ok { return .json(["ok": true, "state": result.message]) }
            return .json(["ok": false, "error": result.message], status: 409)
        }
        return .json(["error": "not found"], status: 404)
    }

    private func gameDict(_ g: Game) -> [String: Any] {
        let m = lib.meta[g.appid]
        if m == nil { lib.ensureMeta(g.appid) }    // fetched in the background; the next request has it
        let st = lib.status[g.id]
        return [
            "id": g.id,
            "appid": g.appid,
            "name": g.name,
            "env": g.side.rawValue,
            "description": m?.description ?? "",
            "shortDescription": m?.shortDescription ?? "",
            "genres": m?.genres ?? [],
            "developer": m?.developer ?? "",
            "released": m?.released ?? "",
            "sizeBytes": g.size,
            "installedAt": g.updated,
            "running": st == "Playing",
            "starting": (st != nil && st != "Playing"),
        ]
    }

    private func orNull(_ v: Any?) -> Any { v ?? NSNull() }

    private func statusDict() async -> [String: Any] {
        let snap = await lib.snapshot()
        let ids = lib.games.map { $0.id }
        let launching: String? = ids.first(where: { lib.status[$0] != nil && lib.status[$0] != "Playing" })
        let playing: String? = snap.playing ?? ids.first(where: { lib.status[$0] == "Playing" })
        var env: String? = nil
        if snap.mac { env = "mac" } else if snap.windows { env = "windows" }
        let pg = Shell.run("/usr/bin/pgrep", ["-x", "sunshine"]).trimmingCharacters(in: .whitespacesAndNewlines)
        var out: [String: Any] = [:]
        out["steamEnv"] = orNull(env)
        out["steam"] = ["mac": snap.mac, "windows": snap.windows]
        out["launching"] = orNull(launching)
        out["playing"] = orNull(playing)
        out["sunshine"] = !pg.isEmpty
        out["steamClosesInSeconds"] = orNull(lib.idleLeft)
        return out
    }

    private func cover(_ g: Game, kind: String) async -> HTTPResponse {
        var img: NSImage?
        if kind == "header" {
            img = await Remote.image(g.appid, .header)
            if img == nil { img = await Remote.storeImage(g.appid) }
        } else {
            img = await Remote.image(g.appid, .poster)
            if img == nil { img = await Remote.apiPoster(g.appid) }
            if img == nil { img = await Remote.image(g.appid, .header) }
            if img == nil { img = await Remote.storeImage(g.appid) }
        }
        guard let image = img, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return .json(["error": "no cover"], status: 404)
        }
        var resp = HTTPResponse(status: 200, contentType: "image/jpeg", body: jpg)
        resp.cache = "max-age=3600"
        return resp
    }
}
