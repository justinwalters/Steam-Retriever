import Foundation

enum Side: String, Codable, CaseIterable {
    case mac, windows
    var label: String { self == .mac ? "Mac" : "CrossOver" }
    var folder: String { self == .mac ? "Mac" : "Windows" }
}

enum PlayMode { case auto, steam, direct }

struct Game: Identifiable, Codable, Hashable {
    let appid: Int
    let name: String
    let installdir: String
    let size: Int64
    let side: Side
    let updated: Int
    var needsSteam: Bool?        // nil = not analysed yet; false = looks launchable without Steam
    var directTarget: String?    // .app (Mac) or .exe (Windows) used for a direct launch
    var id: String { "\(side.rawValue)-\(appid)" }
}

struct Meta: Codable {
    var description: String
    var genres: [String]
    var developer: String
    var released: String
}

enum Config {
    static let cxstart = "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/cxstart"
    static let bottle = "Steam"
    static let winSteam = "C:\\Program Files (x86)\\Steam\\steam.exe"
    static let steamBundle = "com.valvesoftware.steam"
    static let quietArgs = ["-silent", "-nofriendsui", "-no-browser"]
    /// Idle time (no game running or starting) after which a running Steam is closed.
    static let idleLimit: TimeInterval = 300

    /// /Volumes/STEAM first, then any "STEAM 1"-style clash name.
    static func volumeRoots() -> [URL] {
        let fm = FileManager.default
        var out: [URL] = []
        let primary = URL(fileURLWithPath: "/Volumes/STEAM")
        if fm.fileExists(atPath: primary.path) { out.append(primary) }
        if let names = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for n in names.sorted() where n.hasPrefix("STEAM") && n != "STEAM" {
                out.append(URL(fileURLWithPath: "/Volumes/\(n)"))
            }
        }
        return out
    }

    /// The folder that contains `steamapps` for one side (accepts an optional SteamLibrary level).
    static func libraryRoot(_ side: Side) -> URL? {
        let fm = FileManager.default
        for vol in volumeRoots() {
            let base = vol.appendingPathComponent(side.folder)
            for cand in [base, base.appendingPathComponent("SteamLibrary")] {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: cand.appendingPathComponent("steamapps").path, isDirectory: &isDir), isDir.boolValue {
                    return cand
                }
            }
        }
        return nil
    }
}

enum Prefs {
    static var quiet: Bool { UserDefaults.standard.bool(forKey: "quiet") }
    static var quitOnClose: Bool { UserDefaults.standard.bool(forKey: "quitOnClose") }
    static var skipSteam: Bool { UserDefaults.standard.bool(forKey: "skipSteam") }

    /// Games the user chose not to put in full screen automatically.
    static func fullscreenExcluded(_ id: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: "noFullscreen") ?? []).contains(id)
    }
    static func toggleFullscreenExclusion(_ id: String) {
        var list = UserDefaults.standard.stringArray(forKey: "noFullscreen") ?? []
        if let i = list.firstIndex(of: id) { list.remove(at: i) } else { list.append(id) }
        UserDefaults.standard.set(list, forKey: "noFullscreen")
    }
}

extension Meta {
    /// A blurb that fits on a card without truncation: whole sentences up to `limit` characters.
    var shortDescription: String { Meta.shorten(description, limit: 150) }

    /// Cut at a clause boundary (or a word) within `max` characters and end it with a full stop.
    static func cutClause(_ text: String, max: Int) -> String {
        let prefix = String(text.prefix(max))
        let marks: [Character] = [",", ";", ":", "\u{2014}", "\u{2013}"]
        var out: String
        if let c = prefix.lastIndex(where: { marks.contains($0) }),
           prefix.distance(from: prefix.startIndex, to: c) >= 25 {
            out = String(prefix[..<c])
        } else if let sp = prefix.lastIndex(of: " ") {
            out = String(prefix[..<sp])
        } else {
            out = prefix
        }
        out = out.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-\u{2013}\u{2014}"))
        return out + "."
    }

    static func shorten(_ text: String, limit: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= limit { return t }
        var sentences: [String] = []
        var cur: [Substring] = []
        for w in t.split(separator: " ") {
            cur.append(w)
            if let l = w.last, ".!?".contains(l), w.count > 3 || l != "." {
                sentences.append(cur.joined(separator: " "))
                cur = []
            }
        }
        if !cur.isEmpty { sentences.append(cur.joined(separator: " ")) }
        var out = ""
        var used = 0
        for s in sentences {
            let cand = out.isEmpty ? s : out + " " + s
            if cand.count <= limit { out = cand; used += 1 } else { break }
        }
        if out.isEmpty { return cutClause(t, max: limit) }
        // A very short result: add the start of the next sentence, cut cleanly.
        if out.count < 80, used < sentences.count {
            let room = limit - out.count - 1
            if room >= 40 { out += " " + cutClause(sentences[used], max: room) }
        }
        return out
    }
}
