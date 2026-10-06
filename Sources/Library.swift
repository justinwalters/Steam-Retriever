import SwiftUI
import AppKit

@MainActor
final class Library: ObservableObject {
    @Published var games: [Game] = []
    @Published var found: [Side: Bool] = [.mac: true, .windows: true]
    @Published var meta: [Int: Meta] = [:]
    @Published var status: [String: String] = [:]
    @Published var notice: String?
    @Published var loaded = false
    @Published var splashGame: String?        // non-nil while the "fetching your game" dialog is up
    @Published var splashPhase = ""
    @Published var idleLeft: Int?               // seconds until idle Steam is closed, when counting down
    @Published var pairingCode: String?         // shown while an Apple TV pairing is open

    private var watchers: [DispatchSourceFileSystemObject] = []
    private var rescanTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var metaInflight = Set<Int>()
    private lazy var launcher = Launcher(lib: self)
    private lazy var api = APIServer(lib: self)
    private var pairTask: Task<Void, Never>?

    private static let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SteamHub")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("games.json")
    }()

    init() {
        // Paint instantly from the last scan, then refresh.
        if let d = try? Data(contentsOf: Self.cacheURL), let g = try? JSONDecoder().decode([Game].self, from: d) {
            games = g
        }
        rescan()
        installWatchers()
        launcher.startWatchdog()
        if UserDefaults.standard.bool(forKey: "apiEnabled") { api.start() }
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.installWatchers()
                    self?.scheduleRescan()
                }
            }
        }
    }

    // MARK: scanning
    func rescan() {
        let old = games
        Task.detached(priority: .userInitiated) { [weak self] in
            var result: [Game] = []
            var foundMap: [Side: Bool] = [:]
            for side in Side.allCases {
                if let g = LibraryScanner.scan(side) {
                    result += g
                    foundMap[side] = true
                } else {
                    foundMap[side] = false
                    result += old.filter { $0.side == side }     // keep last known games while the drive is away
                }
            }
            var oldMap: [String: Game] = [:]
            for g in old { oldMap[g.id] = g }
            result = result.map { g in
                var g = g
                if let o = oldMap[g.id], o.updated == g.updated, o.needsSteam != nil {
                    g.needsSteam = o.needsSteam
                    g.directTarget = o.directTarget
                }
                return g
            }
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let finalList = result, fm = foundMap
            await MainActor.run { self?.apply(finalList, fm) }
        }
    }

    private func apply(_ list: [Game], _ foundMap: [Side: Bool]) {
        if list != games { games = list; save() }
        found = foundMap
        loaded = true
        analyzeMissing()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(games) { try? d.write(to: Self.cacheURL) }
    }

    private func analyzeMissing() {
        let todo = games.filter { $0.needsSteam == nil }
        guard !todo.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            for g in todo {
                let (needs, target) = LibraryScanner.analyze(g)
                await MainActor.run { self?.setAnalysis(g.id, needs, target) }
            }
        }
    }

    private func setAnalysis(_ id: String, _ needs: Bool, _ target: String?) {
        guard let i = games.firstIndex(where: { $0.id == id }) else { return }
        games[i].needsSteam = needs
        games[i].directTarget = target
        save()
    }

    func scheduleRescan() {
        rescanTask?.cancel()
        rescanTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { self?.rescan() }
        }
    }

    private func installWatchers() {
        watchers.forEach { $0.cancel() }
        watchers = []
        for side in Side.allCases {
            guard let root = Config.libraryRoot(side) else { continue }
            let fd = open(root.appendingPathComponent("steamapps").path, O_EVTONLY)
            if fd < 0 { continue }
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .delete, .rename, .extend], queue: .main)
            src.setEventHandler { [weak self] in Task { @MainActor in self?.scheduleRescan() } }
            src.setCancelHandler { close(fd) }
            src.resume()
            watchers.append(src)
        }
    }

    // MARK: details
    func ensureMeta(_ appid: Int) {
        if meta[appid] != nil || metaInflight.contains(appid) { return }
        metaInflight.insert(appid)
        Task {
            if let m = await Remote.meta(appid) { meta[appid] = m }
            metaInflight.remove(appid)
        }
    }

    // MARK: status + launching
    func setStatus(_ id: String, _ s: String?) {
        if let s = s { status[id] = s } else { status.removeValue(forKey: id) }
    }

    func notify(_ text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled { self?.notice = nil }
        }
    }

    func play(_ g: Game, mode: PlayMode = .auto) {
        if let busy = games.first(where: { status[$0.id] != nil }) {
            notify(busy.id == g.id ? "\(g.name) is already running." : "Finish \(busy.name) first.")
            return
        }
        launcher.play(g, mode: mode)
    }

    // MARK: Apple TV API
    func setAPI(_ on: Bool) {
        if on { api.start() } else { api.stop(); pairingCode = nil }
    }

    func beginPairing() {
        if !UserDefaults.standard.bool(forKey: "apiEnabled") { UserDefaults.standard.set(true, forKey: "apiEnabled") }
        api.start()
        let code = api.beginPairing()
        pairingCode = code
        notify("Enter \(code) on your Apple TV to pair it.")
        pairTask?.cancel()
        pairTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000_000)
            if !Task.isCancelled { self?.api.endPairing(); self?.pairingCode = nil }
        }
    }

    func pairingDone() {
        pairTask?.cancel()
        pairingCode = nil
        notify("Apple TV paired.")
    }

    func snapshot() async -> (mac: Bool, windows: Bool, playing: String?) {
        await launcher.snapshot()
    }

    /// Start a game on behalf of the Apple TV app. Returns whether it was accepted and a short state/reason.
    func startFromAPI(_ g: Game) -> (ok: Bool, message: String) {
        if let busy = games.first(where: { status[$0.id] != nil }) {
            if busy.id == g.id { return (true, status[g.id] == "Playing" ? "playing" : "starting") }
            return (false, "Finish \(busy.name) first.")
        }
        launcher.play(g, mode: .auto)
        return (true, "starting")
    }

    func showInFinder(_ g: Game) {
        guard let root = Config.libraryRoot(g.side) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([root.appendingPathComponent("steamapps/common/\(g.installdir)")])
    }

    func openStorePage(_ g: Game) {
        if let u = URL(string: "https://store.steampowered.com/app/\(g.appid)") { NSWorkspace.shared.open(u) }
    }
}
