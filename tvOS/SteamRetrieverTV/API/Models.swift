// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// JSON shapes from Sources/APIServer.swift on main and docs/tvos-handoff.md.

import Foundation

enum GameEnv: String, Codable, Hashable, CaseIterable {
    case mac, windows

    var label: String { self == .mac ? "Mac" : "Windows" }
}

struct Game: Identifiable, Hashable, Decodable {
    let id: String
    let appid: Int
    let name: String
    let env: GameEnv
    var description: String
    var shortDescription: String
    var genres: [String]
    var developer: String
    var released: String
    var sizeBytes: Int64
    var installedAt: Int
    var running: Bool
    var starting: Bool

    /// The real server fetches store metadata in the background, so these can be empty on the first call.
    var hasMeta: Bool { !description.isEmpty || !developer.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case id, appid, name, env, description, shortDescription, genres, developer, released
        case sizeBytes, installedAt, running, starting
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        appid = try c.decodeIfPresent(Int.self, forKey: .appid) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        let envRaw = try c.decodeIfPresent(String.self, forKey: .env) ?? ""
        env = GameEnv(rawValue: envRaw) ?? (id.hasPrefix("mac-") ? .mac : .windows)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        shortDescription = try c.decodeIfPresent(String.self, forKey: .shortDescription) ?? ""
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        developer = try c.decodeIfPresent(String.self, forKey: .developer) ?? ""
        released = try c.decodeIfPresent(String.self, forKey: .released) ?? ""
        sizeBytes = try c.decodeIfPresent(Int64.self, forKey: .sizeBytes) ?? 0
        installedAt = try c.decodeIfPresent(Int.self, forKey: .installedAt) ?? 0
        running = try c.decodeIfPresent(Bool.self, forKey: .running) ?? false
        starting = try c.decodeIfPresent(Bool.self, forKey: .starting) ?? false
    }

    /// For previews and tests.
    init(id: String, name: String, env: GameEnv, description: String = "", genres: [String] = [],
         developer: String = "", installedAt: Int = 0) {
        self.id = id
        self.appid = Int(id.split(separator: "-").last ?? "") ?? 0
        self.name = name
        self.env = env
        self.description = description
        self.shortDescription = description
        self.genres = genres
        self.developer = developer
        self.released = ""
        self.sizeBytes = 0
        self.installedAt = installedAt
        self.running = false
        self.starting = false
    }
}

struct ServerStatus: Decodable, Equatable {
    struct SteamRunning: Decodable, Equatable {
        var mac: Bool
        var windows: Bool
    }

    var steamEnv: String?
    var steam: SteamRunning?
    var launching: String?
    var playing: String?
    var sunshine: Bool
    var steamClosesInSeconds: Int?

    var env: GameEnv? { steamEnv.flatMap(GameEnv.init(rawValue:)) }

    private enum CodingKeys: String, CodingKey {
        case steamEnv, steam, launching, playing, sunshine, steamClosesInSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        steamEnv = try c.decodeIfPresent(String.self, forKey: .steamEnv)
        steam = try c.decodeIfPresent(SteamRunning.self, forKey: .steam)
        launching = try c.decodeIfPresent(String.self, forKey: .launching)
        playing = try c.decodeIfPresent(String.self, forKey: .playing)
        sunshine = try c.decodeIfPresent(Bool.self, forKey: .sunshine) ?? true
        steamClosesInSeconds = try c.decodeIfPresent(Int.self, forKey: .steamClosesInSeconds)
    }
}

struct PingResponse: Decodable {
    var app: String
    var api: Int
}

enum LaunchState: String {
    case starting, playing
}

enum CoverKind: String {
    case poster, header
}
