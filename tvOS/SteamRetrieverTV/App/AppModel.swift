// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// App state and flow: splash -> probe -> Setup | Home -> Launching -> Streaming -> Home.
// Every wait here has a timeout, and every screen that waits has a way to Settings.

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Screen: Equatable { case splash, setup, home, launching, streaming }

    enum SetupStep: Int, CaseIterable, Identifiable {
        case findMac, pairRetriever, pairSunshine, test
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .findMac: return "Find the Mac"
            case .pairRetriever: return "Pair Steam Retriever"
            case .pairSunshine: return "Pair streaming"
            case .test: return "Test"
            }
        }
    }

    enum NavSection: String, CaseIterable, Identifiable {
        case home, library, mac, windows, search, nowPlaying, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: return "Home"
            case .library: return "Library"
            case .mac: return "Mac"
            case .windows: return "Windows"
            case .search: return "Search"
            case .nowPlaying: return "Now Playing"
            case .settings: return "Settings"
            }
        }
        var symbol: String {
            switch self {
            case .home: return "house.fill"
            case .library: return "square.grid.2x2.fill"
            case .mac: return "apple.logo"
            case .windows: return "pc"
            case .search: return "magnifyingglass"
            case .nowPlaying: return "play.circle.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    enum StepState: Equatable {
        case pending, running, ok
        case failed(String)
        case skipped(String)
    }

    enum LaunchPhase: Equatable {
        case requesting
        case waiting(String)
        case failed(String, fix: SetupStep?)
    }

    struct TestCheck: Identifiable, Equatable {
        let id: String
        var state: StepState
    }

    // MARK: state the UI reads

    var screen: Screen = .splash
    var splashMessage = "Fetching your games\u{2026}"

    var host: SavedHost? = HostStore.host
    var games: [Game] = []
    var status: ServerStatus?
    var libraryError: String?
    var notice: String?
    var focusedGameID: String?
    var detailGame: Game?
    var navSection: NavSection = .home

    var setupStep: SetupStep = .findMac
    var setupReason: String?
    var stepStates: [SetupStep: StepState] = [:]
    var sunshinePIN: String?
    var testChecks: [TestCheck] = []

    var launchGame: Game?
    var launchPhase: LaunchPhase = .requesting
    var launchStarted = Date()

    let discovery: HostDiscovery
    let streamer: StreamLauncher

    @ObservationIgnored private var launchTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    static let launchPollInterval: UInt64 = 2_000_000_000
    static let launchTimeout: TimeInterval = 6 * 60
    static let homePollInterval: UInt64 = 5_000_000_000

    init(streamer: StreamLauncher) {
        self.streamer = streamer
        self.discovery = HostDiscovery()
    }

    // MARK: derived

    var api: RetrieverAPI? {
        guard let host, let base = RetrieverAPI.baseURL(for: host.address) else { return nil }
        return RetrieverAPI(baseURL: base, token: HostStore.token)
    }

    /// Host name/IP without the port, for Moonlight.
    var streamHost: String? {
        api?.baseURL.host
    }

    var focusedGame: Game? {
        games.first { $0.id == focusedGameID } ?? continueGames.first ?? games.first
    }

    var continueGames: [Game] { PlayHistory.continueList(games) }
    var recentGames: [Game] { Array(games.sorted { $0.installedAt > $1.installedAt }.prefix(12)) }
    var allGames: [Game] { games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
    func games(for env: GameEnv) -> [Game] { allGames.filter { $0.env == env } }

    var sunshinePaused: Bool { status?.sunshine == false }
    var playingGame: Game? { games.first { $0.id == status?.playing } }

    // MARK: start-up

    enum ProbeResult {
        case ok(ServerStatus?)
        case needsSetup(SetupStep, String?)
    }

    func start() async {
        discovery.start()
        async let minimumSplash: Void = Self.pause(seconds: 1.2)   // let Sprocket be seen
        let result = await probeSavedHost()
        await minimumSplash
        switch result {
        case .ok(let s):
            status = s
            if let streamHost, case .notPaired = await streamer.sunshinePairing(host: streamHost) {
                openSetup(at: .pairSunshine, reason: "This Apple TV isn't paired with Sunshine on the Mac yet.")
            } else {
                enterHome()
            }
        case .needsSetup(let step, let reason):
            openSetup(at: step, reason: reason)
        }
    }

    /// Direct check (ping 2 s, then status) raced against Bonjour seeing the saved Mac.
    func probeSavedHost() async -> ProbeResult {
        guard let host else { return .needsSetup(.findMac, nil) }   // first run: no complaint
        guard let api else { return .needsSetup(.findMac, "The saved address \"\(host.address)\" isn't valid.") }
        guard api.token != nil else {
            return .needsSetup(.pairRetriever, "Pair this Apple TV with Steam Retriever on the Mac.")
        }
        splashMessage = "Looking for \(host.serviceName ?? host.address)\u{2026}"
        let serviceName = host.serviceName

        return await withTaskGroup(of: ProbeResult?.self) { group in
            group.addTask { await Self.directProbe(api) }
            if let serviceName {
                group.addTask { await self.waitForBonjour(serviceName, timeout: 3) ? .ok(nil) : nil }
            }
            var fallback: ProbeResult = .needsSetup(.findMac, "Couldn't find the Mac.")
            for await r in group {
                guard let r else { continue }
                switch r {
                case .ok:
                    group.cancelAll()
                    return r
                case .needsSetup(.pairRetriever, _):
                    group.cancelAll()      // a 401 is definitive; don't let Bonjour paper over it
                    return r
                case .needsSetup:
                    fallback = r           // keep waiting in case Bonjour sees it
                }
            }
            return fallback
        }
    }

    nonisolated static func directProbe(_ api: RetrieverAPI) async -> ProbeResult {
        do {
            _ = try await api.ping()
        } catch {
            return .needsSetup(.findMac, (error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
        do {
            return .ok(try await api.status())
        } catch APIError.unauthorized {
            return .needsSetup(.pairRetriever, APIError.unauthorized.errorDescription)
        } catch {
            return .needsSetup(.findMac, (error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    private func waitForBonjour(_ name: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !Task.isCancelled {
            if discovery.macs.contains(where: { $0.name == name }) { return true }
            await Self.pause(seconds: 0.25)
        }
        return false
    }

    nonisolated static func pause(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // MARK: home

    func enterHome() {
        screen = .home
        libraryError = nil
        Task { await refreshLibrary() }
        startHomePolling()
    }

    func refreshLibrary() async {
        guard let api else { return openSetup(at: .findMac, reason: nil) }
        do {
            games = try await api.games()
            libraryError = nil
            if focusedGameID == nil { focusedGameID = focusedGame?.id }
            // Store descriptions are fetched on the Mac the first time; ask again shortly.
            if games.contains(where: { !$0.hasMeta }) {
                Task {
                    await Self.pause(seconds: 4)
                    if let fresh = try? await api.games() { games = fresh }
                }
            }
        } catch APIError.unauthorized {
            openSetup(at: .pairRetriever, reason: APIError.unauthorized.errorDescription)
        } catch {
            libraryError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    private func startHomePolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.screen == .home, let api = self.api else { return }
                do {
                    self.status = try await api.status()
                } catch APIError.unauthorized {
                    self.openSetup(at: .pairRetriever, reason: APIError.unauthorized.errorDescription)
                    return
                } catch {
                    // Transient; the banner/library error covers persistent failures.
                }
                try? await Task.sleep(nanoseconds: Self.homePollInterval)
            }
        }
    }

    // MARK: playing

    func play(_ game: Game) {
        guard !sunshinePaused else { return }
        detailGame = nil
        pollTask?.cancel()
        launchTask?.cancel()
        launchGame = game
        launchPhase = .requesting
        launchStarted = Date()
        screen = .launching
        launchTask = Task { await runLaunch(game) }
    }

    private func runLaunch(_ game: Game) async {
        guard let api else { return openSetup(at: .findMac, reason: nil) }
        do {
            if try await api.launch(game.id) != .playing {
                try await waitUntilPlaying(game, api: api)
            }
            PlayHistory.markPlayed(game.id)
            screen = .streaming
        } catch is CancellationError {
            // user backed out
        } catch APIError.unauthorized {
            launchPhase = .failed(APIError.unauthorized.errorDescription ?? "", fix: .pairRetriever)
        } catch APIError.conflict(let message) {
            launchPhase = .failed(message, fix: nil)
        } catch let e as LaunchFailure {
            launchPhase = .failed(e.message, fix: nil)
        } catch {
            launchPhase = .failed((error as? LocalizedError)?.errorDescription ?? "\(error)", fix: .findMac)
        }
    }

    private struct LaunchFailure: Error { let message: String }

    private func waitUntilPlaying(_ game: Game, api: RetrieverAPI) async throws {
        let deadline = launchStarted.addingTimeInterval(Self.launchTimeout)
        var sawStarting = false
        var gone = 0
        launchPhase = .waiting("Asking the Mac to start \(game.name)\u{2026}")
        while true {
            try Task.checkCancellation()
            if Date() > deadline {
                throw LaunchFailure(message: "\(game.name) didn't start within 6 minutes. Check the Mac.")
            }
            do {
                let s = try await api.status()
                status = s
                if s.playing == game.id { return }
                if s.launching == game.id {
                    sawStarting = true
                    gone = 0
                } else if sawStarting {
                    gone += 1    // was starting, now neither starting nor playing
                    if gone >= 2 { throw LaunchFailure(message: "\(game.name) stopped before it finished starting.") }
                }
                launchPhase = .waiting(Self.describe(s, game: game))
            } catch APIError.unauthorized {
                throw APIError.unauthorized
            } catch let e as LaunchFailure {
                throw e
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                launchPhase = .waiting("Waiting for the Mac to answer\u{2026}")
            }
            try await Task.sleep(nanoseconds: Self.launchPollInterval)
        }
    }

    static func describe(_ s: ServerStatus, game: Game) -> String {
        guard s.launching == game.id else { return "Waiting for \(game.name)\u{2026}" }
        if let env = s.env, env != game.env {
            return "Switching to \(game.env.label) Steam\u{2026}"
        }
        let running = game.env == .mac ? s.steam?.mac : s.steam?.windows
        if running == false { return "Starting \(game.env.label) Steam\u{2026}" }
        return "Starting \(game.name)\u{2026}"
    }

    func retryLaunch() {
        if let launchGame { play(launchGame) }
    }

    /// Back to the library; the game keeps starting on the Mac.
    func leaveLaunch() {
        launchTask?.cancel()
        enterHome()
    }

    func streamEnded(_ end: StreamEnd) {
        if case .failed(let why) = end { notice = "The stream stopped: \(why)" }
        enterHome()
    }

    // MARK: setup

    func openSetup(at step: SetupStep, reason: String?) {
        pollTask?.cancel()
        launchTask?.cancel()
        setupStep = step
        setupReason = reason
        if let reason { stepStates[step] = .failed(reason) }
        screen = .setup
    }

    func leaveSetup() {
        if api?.token != nil { enterHome() }
    }

    /// Step 1, from the Bonjour list.
    func connect(to found: HostDiscovery.Found) async {
        stepStates[.findMac] = .running
        guard let address = await HostDiscovery.resolve(found.endpoint) else {
            stepStates[.findMac] = .failed("Found \"\(found.name)\" but couldn't get its address. Type it in instead.")
            return
        }
        await connect(address: address, serviceName: found.name)
    }

    /// Step 1, typed address (or resolved from Bonjour).
    func connect(address: String, serviceName: String? = nil) async {
        stepStates[.findMac] = .running
        guard let base = RetrieverAPI.baseURL(for: address) else {
            stepStates[.findMac] = .failed(APIError.badAddress(address).errorDescription ?? "")
            return
        }
        do {
            _ = try await RetrieverAPI(baseURL: base).ping()
        } catch {
            stepStates[.findMac] = .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")
            return
        }
        let changed = host?.address != address
        host = SavedHost(address: address, serviceName: serviceName)
        HostStore.host = host
        stepStates[.findMac] = .ok
        if changed { stepStates[.pairRetriever] = .pending }

        // Already paired with this Mac? Skip ahead.
        if let api, api.token != nil, (try? await api.status()) != nil {
            stepStates[.pairRetriever] = .ok
            setupStep = .pairSunshine
        } else {
            setupStep = .pairRetriever
        }
    }

    /// Step 2: the 6-digit code from the Mac app's gear menu > Pair Apple TV...
    func pair(code: String) async {
        let digits = code.filter(\.isNumber)
        guard digits.count == 6 else {
            stepStates[.pairRetriever] = .failed("The code is 6 digits.")
            return
        }
        guard let host, let base = RetrieverAPI.baseURL(for: host.address) else {
            setupStep = .findMac
            return
        }
        stepStates[.pairRetriever] = .running
        do {
            HostStore.token = try await RetrieverAPI(baseURL: base).pair(code: digits, deviceName: Self.deviceName)
            stepStates[.pairRetriever] = .ok
            setupStep = .pairSunshine
        } catch {
            stepStates[.pairRetriever] = .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    /// Step 3: Moonlight's pairing with Sunshine.
    func pairSunshine() async {
        guard let streamHost else { setupStep = .findMac; return }
        stepStates[.pairSunshine] = .running
        switch await streamer.sunshinePairing(host: streamHost) {
        case .paired:
            stepStates[.pairSunshine] = .ok
            setupStep = .test
            return
        case .unavailable(let why):
            stepStates[.pairSunshine] = .skipped(why)
            setupStep = .test
            return
        case .unreachable(let why):
            stepStates[.pairSunshine] = .failed(why)
            return
        case .notPaired:
            break
        }
        do {
            try await streamer.pairSunshine(host: streamHost) { [weak self] pin in self?.sunshinePIN = pin }
            sunshinePIN = nil
            stepStates[.pairSunshine] = .ok
            setupStep = .test
        } catch {
            sunshinePIN = nil
            stepStates[.pairSunshine] = .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    /// Step 4: ping, token, Sunshine running, Sunshine paired. (Test stream joins in phase 3.)
    func runTest() async {
        stepStates[.test] = .running
        testChecks = ["Mac answers", "Paired with Steam Retriever", "Sunshine running", "Streaming paired"]
            .map { TestCheck(id: $0, state: .pending) }
        func set(_ i: Int, _ s: StepState) { testChecks[i].state = s }

        guard let api else { set(0, .failed("No Mac chosen.")); return finishTest(fix: .findMac) }
        set(0, .running)
        do { _ = try await api.ping(); set(0, .ok) } catch {
            set(0, .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")); return finishTest(fix: .findMac)
        }
        set(1, .running)
        let s: ServerStatus
        do { s = try await api.status(); status = s; set(1, .ok) } catch {
            set(1, .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")); return finishTest(fix: .pairRetriever)
        }
        set(2, s.sunshine ? .ok : .failed("Sunshine is paused on the Mac. Turn it on with Sunshine Switch."))
        set(3, .running)
        switch await streamer.sunshinePairing(host: streamHost ?? "") {
        case .paired: set(3, .ok)
        case .unavailable(let why): set(3, .skipped(why))
        case .notPaired: set(3, .failed("Not paired yet.")); return finishTest(fix: .pairSunshine)
        case .unreachable(let why): set(3, .failed(why)); return finishTest(fix: .pairSunshine)
        }
        finishTest(fix: s.sunshine ? nil : .test)
    }

    private func finishTest(fix: SetupStep?) {
        let failed = testChecks.first { if case .failed = $0.state { return true } else { return false } }
        if let failed, case .failed(let why) = failed.state {
            stepStates[.test] = .failed(why)
            if let fix, fix != .test { stepStates[fix] = .failed(why) }
        } else {
            stepStates[.test] = .ok
        }
    }

    var testPassed: Bool { stepStates[.test] == .ok }

    static var deviceName: String { "Apple TV" }
}
