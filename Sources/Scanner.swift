import Foundation

/// Reads Steam appmanifest files and inspects game folders. Pure functions, safe off the main thread.
enum LibraryScanner {
    private static let kv = try! NSRegularExpression(pattern: "\"([^\"]+)\"\\s+\"([^\"]*)\"")

    static func parse(_ url: URL) -> [String: String]? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let ns = text as NSString
        var out: [String: String] = [:]
        for m in kv.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let k = ns.substring(with: m.range(at: 1)).lowercased()
            if out[k] == nil { out[k] = ns.substring(with: m.range(at: 2)) }
        }
        return out
    }

    /// nil means the library folder could not be found (drive not connected).
    static func scan(_ side: Side) -> [Game]? {
        guard let root = Config.libraryRoot(side) else { return nil }
        let apps = root.appendingPathComponent("steamapps")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: apps.path) else { return nil }
        var games: [Game] = []
        for n in names where n.hasPrefix("appmanifest_") && n.hasSuffix(".acf") {
            guard let v = parse(apps.appendingPathComponent(n)),
                  let appid = Int(v["appid"] ?? ""),
                  let flags = Int(v["stateflags"] ?? "0"), flags & 4 != 0 else { continue }
            let installdir = v["installdir"] ?? ""
            let name = (v["name"]?.isEmpty == false ? v["name"]! : installdir)
            games.append(Game(appid: appid, name: name, installdir: installdir,
                              size: Int64(v["sizeondisk"] ?? "0") ?? 0, side: side,
                              updated: Int(v["lastupdated"] ?? "0") ?? 0,
                              needsSteam: nil, directTarget: nil))
        }
        return games
    }

    private static let steamLibs: Set<String> = [
        "steam_api.dll", "steam_api64.dll", "libsteam_api.dylib", "libsteam_api.so",
        "steamworks.net.dll", "facepunch.steamworks.win64.dll", "facepunch.steamworks.win32.dll",
    ]
    private static let notTheGame = ["unins", "crash", "redist", "dxsetup", "dotnet", "uninstall",
                                     "setup", "vcredist", "vc_redist", "ue4prereq", "installer", "report"]

    /// Heuristic: can this game start without the Steam client?
    /// Returns (needsSteam, launch target). Not a guarantee, the hub falls back to Steam if it doesn't start.
    static func analyze(_ g: Game) -> (Bool, String?) {
        guard let root = Config.libraryRoot(g.side) else { return (true, nil) }
        let dir = root.appendingPathComponent("steamapps/common/\(g.installdir)")
        let fm = FileManager.default

        var usesSteamworks = false
        if let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            var count = 0
            for case let u as URL in en {
                count += 1
                if count > 30000 { break }
                if steamLibs.contains(u.lastPathComponent.lowercased()) { usesSteamworks = true; break }
            }
        }

        let top = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey],
                                               options: [.skipsHiddenFiles])) ?? []
        var target: String?
        switch g.side {
        case .mac:
            target = top.first(where: { $0.pathExtension == "app" })?.path
        case .windows:
            let exes = top.filter { u in
                guard u.pathExtension.lowercased() == "exe" else { return false }
                let n = u.lastPathComponent.lowercased()
                return !notTheGame.contains(where: { n.contains($0) })
            }
            func size(_ u: URL) -> Int { (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 }
            target = exes.max(by: { size($0) < size($1) })?.path
        }

        if usesSteamworks || target == nil { return (true, target) }
        if g.side == .windows, let t = target, hasSteamStub(t) { return (true, target) }
        return (false, target)
    }

    /// SteamStub DRM adds a ".bind" section to the executable.
    static func hasSteamStub(_ path: String) -> Bool {
        guard let fh = FileHandle(forReadingAtPath: path) else { return true }
        defer { try? fh.close() }
        guard let d = try? fh.read(upToCount: 4096) else { return true }
        let b = [UInt8](d)
        func u16(_ o: Int) -> Int { o >= 0 && o + 2 <= b.count ? Int(b[o]) | Int(b[o + 1]) << 8 : -1 }
        func u32(_ o: Int) -> Int { o >= 0 && o + 4 <= b.count ? u16(o) | u16(o + 2) << 16 : -1 }
        let pe = u32(0x3C)
        guard pe > 0, pe + 24 < b.count, b[pe] == 0x50, b[pe + 1] == 0x45 else { return true }
        let n = u16(pe + 6), opt = u16(pe + 20)
        var o = pe + 24 + opt
        for _ in 0..<min(max(n, 0), 40) {
            guard o + 8 <= b.count else { return true }
            let raw = b[o..<o + 8].prefix(while: { $0 != 0 })
            let name = String(decoding: raw, as: UTF8.self)
            if name == ".bind" { return true }
            o += 40
        }
        return false
    }
}
