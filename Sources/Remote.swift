import AppKit

/// Cover art and store descriptions, cached on disk so everything works offline after the first view.
enum Remote {
    static let cacheDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SteamHub")
        for sub in ["meta", "img"] {
            try? FileManager.default.createDirectory(at: base.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        return base
    }()

    private static let bases = [
        "https://cdn.cloudflare.steamstatic.com/steam/apps",
        "https://cdn.akamai.steamstatic.com/steam/apps",
    ]

    // MARK: metadata
    static func meta(_ appid: Int) async -> Meta? {
        let file = cacheDir.appendingPathComponent("meta/\(appid).json")
        if let d = try? Data(contentsOf: file), let m = try? JSONDecoder().decode(Meta.self, from: d) { return m }
        guard let url = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(appid)&l=english") else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15))
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entry = obj[String(appid)] as? [String: Any] else { return nil }
            var m = Meta(description: "", genres: [], developer: "", released: "")
            if (entry["success"] as? Bool) == true, let d = entry["data"] as? [String: Any] {
                m.description = clean((d["short_description"] as? String) ?? "")
                m.genres = ((d["genres"] as? [[String: Any]]) ?? []).compactMap { $0["description"] as? String }
                m.developer = ((d["developers"] as? [String]) ?? []).first ?? ""
                m.released = ((d["release_date"] as? [String: Any])?["date"] as? String) ?? ""
            }
            if let enc = try? JSONEncoder().encode(m) { try? enc.write(to: file) }
            return m
        } catch { return nil }
    }

    private static func clean(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (a, b) in [("&quot;", "\""), ("&amp;", "&"), ("&#39;", "'"), ("&#x27;", "'"),
                       ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&rsquo;", "\u{2019}")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: images
    enum Kind: String { case poster = "library_600x900.jpg", header = "header.jpg" }

    private static let memory = NSCache<NSString, NSImage>()

    static func image(_ appid: Int, _ kind: Kind) async -> NSImage? {
        let key = "\(appid)-\(kind.rawValue)" as NSString
        if let hit = memory.object(forKey: key) { return hit }
        let file = cacheDir.appendingPathComponent("img/\(appid)_\(kind == .poster ? "poster" : "header").jpg")
        let none = file.appendingPathExtension("none")
        if let d = try? Data(contentsOf: file), let img = NSImage(data: d) { memory.setObject(img, forKey: key); return img }
        if FileManager.default.fileExists(atPath: none.path) { return nil }
        var missing = 0
        for base in bases {
            guard let url = URL(string: "\(base)/\(appid)/\(kind.rawValue)") else { continue }
            do {
                let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15))
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200, let img = NSImage(data: data) {
                    try? data.write(to: file)
                    memory.setObject(img, forKey: key)
                    return img
                }
                if code == 404 || code == 403 { missing += 1 }
            } catch { }
        }
        if missing == bases.count { try? Data().write(to: none) }   // really doesn't exist, don't retry
        return nil
    }

    /// Newer apps keep their portrait capsule at hashed addresses; Steam's store API lists them.
    static func apiPoster(_ appid: Int) async -> NSImage? {
        let key = "\(appid)-api" as NSString
        if let hit = memory.object(forKey: key) { return hit }
        let file = cacheDir.appendingPathComponent("img/\(appid)_api.jpg")
        let none = file.appendingPathExtension("none")
        if let d = try? Data(contentsOf: file), let img = NSImage(data: d) { memory.setObject(img, forKey: key); return img }
        if FileManager.default.fileExists(atPath: none.path) { return nil }
        let input = "{\"ids\":[{\"appid\":\(appid)}],\"context\":{\"language\":\"english\",\"country_code\":\"US\"},\"data_request\":{\"include_assets\":true}}"
        guard var comps = URLComponents(string: "https://api.steampowered.com/IStoreBrowseService/GetItems/v1") else { return nil }
        comps.queryItems = [URLQueryItem(name: "input_json", value: input)]
        guard let url = comps.url else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15))
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = root["response"] as? [String: Any],
                  let items = response["store_items"] as? [[String: Any]],
                  let assets = items.first?["assets"] as? [String: Any],
                  let format = assets["asset_url_format"] as? String,
                  let name = (assets["library_capsule_2x"] as? String) ?? (assets["library_capsule"] as? String) else {
                try? Data().write(to: none)       // no portrait art published for this app
                return nil
            }
            let addr = "https://shared.fastly.steamstatic.com/store_item_assets/"
                + format.replacingOccurrences(of: "${FILENAME}", with: name)
            guard let imgURL = URL(string: addr) else { return nil }
            let (imgData, imgResp) = try await URLSession.shared.data(for: URLRequest(url: imgURL, timeoutInterval: 15))
            if (imgResp as? HTTPURLResponse)?.statusCode == 200, let img = NSImage(data: imgData) {
                try? imgData.write(to: file)
                memory.setObject(img, forKey: key)
                return img
            }
        } catch { }
        return nil
    }

    /// Last resort: the image Steam's own store page advertises (og:image), which also covers newer apps
    /// whose art lives at hashed addresses.
    static func storeImage(_ appid: Int) async -> NSImage? {
        let key = "\(appid)-store" as NSString
        if let hit = memory.object(forKey: key) { return hit }
        let file = cacheDir.appendingPathComponent("img/\(appid)_store.jpg")
        let none = file.appendingPathExtension("none")
        if let d = try? Data(contentsOf: file), let img = NSImage(data: d) { memory.setObject(img, forKey: key); return img }
        if FileManager.default.fileExists(atPath: none.path) { return nil }
        guard let page = URL(string: "https://store.steampowered.com/app/\(appid)/?l=english") else { return nil }
        var req = URLRequest(url: page, timeoutInterval: 15)
        req.setValue("birthtime=568022401; lastagecheckage=1-0-1988; wants_mature_content=1", forHTTPHeaderField: "Cookie")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let html = String(decoding: data, as: UTF8.self)
            guard let re = try? NSRegularExpression(pattern: "<meta property=\"og:image\" content=\"([^\"]+)\""),
                  let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let r = Range(m.range(at: 1), in: html),
                  let imgURL = URL(string: String(html[r]).replacingOccurrences(of: "&amp;", with: "&")) else {
                try? Data().write(to: none)
                return nil
            }
            let (imgData, resp) = try await URLSession.shared.data(for: URLRequest(url: imgURL, timeoutInterval: 15))
            if (resp as? HTTPURLResponse)?.statusCode == 200, let img = NSImage(data: imgData) {
                try? imgData.write(to: file)
                memory.setObject(img, forKey: key)
                return img
            }
        } catch { }
        return nil
    }
}
