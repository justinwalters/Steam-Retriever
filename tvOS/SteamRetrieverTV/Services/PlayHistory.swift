// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// "Continue" shelf: last-played times, kept on the Apple TV.

import Foundation

enum PlayHistory {
    private static let key = "playHistory"

    static var lastPlayed: [String: Double] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Double]) ?? [:]
    }

    static func markPlayed(_ id: String) {
        var all = lastPlayed
        all[id] = Date().timeIntervalSince1970
        UserDefaults.standard.set(all, forKey: key)
    }

    /// Games played before, most recent first.
    static func continueList(_ games: [Game], limit: Int = 10) -> [Game] {
        let played = lastPlayed
        return games
            .filter { played[$0.id] != nil }
            .sorted { (played[$0.id] ?? 0) > (played[$1.id] ?? 0) }
            .prefix(limit)
            .map { $0 }
    }
}
