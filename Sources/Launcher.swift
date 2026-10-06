import AppKit

/// Starts games in the right environment and actively manages the Steam clients around them:
/// closes the other client, waits for Steam to be ready, re-asks if a request is lost, restarts a Steam
/// that dies or stalls, and shuts Steam down (escalating to a force-quit) when the game is closed.
@MainActor
final class Launcher {
    unowned let lib: Library
    init(lib: Library) { self.lib = lib }

    func play(_ g: Game, mode: PlayMode) {
        var direct = false
        switch mode {
        case .direct:
            guard g.directTarget != nil else { lib.notify("No launchable app found for \(g.name)."); return }
            direct = true
        case .steam: direct = false
        case .auto: direct = Prefs.skipSteam && g.needsSteam == false && g.directTarget != nil
        }
        lib.setStatus(g.id, "Starting…")
        Task { await run(g, direct: direct) }
    }

    private func phase(_ text: String) {
        lib.splashPhase = text
        Log.write("phase: \(text)")
    }

    // MARK: the session

    private func run(_ g: Game, direct: Bool) async {
        let id = g.id
        let libRef = lib
        defer {
            libRef.setStatus(id, nil)
            libRef.splashGame = nil
        }
        var viaSteam = !direct
        let started = Date()
        Log.write("play \(g.name) [\(g.side.rawValue)] direct=\(direct)")
        phase("Getting things ready")

        // Show the waiting dialog only if this isn't instant.
        let splashTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled { libRef.splashGame = g.name }
        }
        defer { splashTask.cancel() }

        if viaSteam {
            guard await prepareSteam(g) else { Log.write("start aborted"); return }
        } else {
            startDirectly(g)
        }

        var seen = false
        var missing = 0
        var resends = 0
        var restarts = 0
        var lastSend = Date()
        var activated = false

        while true {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let procs = await processes()

            if gameLine(g, in: procs) {
                if !seen {
                    Log.write("game process seen after \(Int(Date().timeIntervalSince(started)))s")
                    splashTask.cancel()
                    libRef.splashGame = nil
                }
                seen = true
                missing = 0
                libRef.setStatus(id, "Playing")
                continue
            }
            if seen {
                missing += 1
                if missing >= 3 { break }
                continue
            }

            let waited = Date().timeIntervalSince(started)

            if !viaSteam && waited > 30 {
                // The direct start didn't take: this one needs Steam after all.
                viaSteam = true
                phase("This game needs Steam, starting it")
                guard await prepareSteam(g) else { return }
                lastSend = Date()
                continue
            }

            if viaSteam {
                if !steamUp(g.side, procs) {
                    // Steam crashed, was closed, or never came up.
                    restarts += 1
                    Log.write("Steam is not running (restart \(restarts))")
                    if restarts > 3 {
                        libRef.notify("Steam keeps stopping. Open it by hand and try again.")
                        return
                    }
                    phase("Steam stopped, starting it again")
                    guard await prepareSteam(g) else { return }
                    lastSend = Date()
                    resends = 0
                    continue
                }
                if Date().timeIntervalSince(lastSend) > 12 && resends < 8 {
                    resends += 1
                    lastSend = Date()
                    phase("Asking Steam again (\(resends))")
                    sendLaunch(g)
                }
                if resends >= 5 && Date().timeIntervalSince(lastSend) > 10 && restarts < 1 {
                    // Steam is up but not acting on requests: restart it from scratch.
                    restarts += 1
                    Log.write("Steam is not responding, restarting it")
                    phase("Steam isn't responding, restarting it")
                    _ = await quitSteam(g.side)
                    guard await prepareSteam(g) else { return }
                    lastSend = Date()
                    resends = 0
                    continue
                }
                if waited > 50 && !activated && g.side == .mac {
                    activated = true
                    Log.write("showing Steam window")
                    Shell.spawn("/usr/bin/open", ["-b", Config.steamBundle])
                    libRef.notify("Steam may need attention. Its window is now open.")
                }
            }

            if waited > 360 {
                Log.write("gave up waiting for the game")
                libRef.notify("\(g.name) didn't start. Steam was left running.")
                return
            }
        }

        Log.write("game closed; Steam stays running for a quick restart (idle timer takes over)")
    }

    // MARK: idle watchdog

    /// Keeps Steam warm between games but closes it once nothing has been playing or starting for a while.
    func startWatchdog() {
        Task { @MainActor [weak self] in
            var idleSince: Date?
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self = self else { return }
                let procs = await self.processes()
                let macUp = self.steamUp(.mac, procs)
                let winUp = self.steamUp(.windows, procs)
                let playing = self.lib.games.contains { self.gameLine($0, in: procs) }
                let busy = !self.lib.status.isEmpty
                if !Prefs.quitOnClose || !(macUp || winUp) || playing || busy {
                    idleSince = nil
                    self.lib.idleLeft = nil
                    continue
                }
                if idleSince == nil { idleSince = Date(); Log.write("idle timer started") }
                let left = Int(Config.idleLimit - Date().timeIntervalSince(idleSince ?? Date()))
                self.lib.idleLeft = max(left, 0)
                if left <= 0 {
                    Log.write("idle for \(Int(Config.idleLimit))s, closing Steam")
                    self.lib.idleLeft = nil
                    idleSince = nil
                    if macUp { _ = await self.quitSteam(.mac) }
                    if winUp { _ = await self.quitSteam(.windows) }
                    self.lib.notify("Steam closed after \(Int(Config.idleLimit) / 60) idle minutes.")
                }
            }
        }
    }

    // MARK: managing Steam

    /// Make sure the other client is closed, this side's Steam is running and ready, and the launch was sent.
    private func prepareSteam(_ g: Game) async -> Bool {
        let other: Side = g.side == .mac ? .windows : .mac
        if await steamRunning(other) {
            let procs = await processes()
            if let playing = lib.games.first(where: { $0.side == other && gameLine($0, in: procs) }) {
                lib.notify("Close \(playing.name) first.")
                return false
            }
            phase("Closing \(other.label) Steam")
            if !(await quitSteam(other)) {
                lib.notify("\(other.label) Steam won't close. Quit it first.")
                return false
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        switch g.side {
        case .windows:
            if await steamRunning(.windows) {
                phase("Asking Steam to start \(g.name)")
                sendLaunch(g)
            } else {
                phase("Waking up Steam")
                var args = ["--bottle", Config.bottle, Config.winSteam]
                if Prefs.quiet { args += Config.quietArgs }
                args += ["-applaunch", String(g.appid)]
                Shell.spawn(Config.cxstart, args)
            }
        case .mac:
            if !(await steamRunning(.mac)) {
                phase("Waking up Steam")
                if Prefs.quiet {
                    Shell.spawn("/usr/bin/open", ["-g", "-b", Config.steamBundle, "--args"] + Config.quietArgs)
                } else {
                    Shell.spawn("/usr/bin/open", ["-b", Config.steamBundle])
                }
                for _ in 0..<60 {
                    if await steamRunning(.mac) { break }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                phase("Waiting for Steam to sign in")
                await waitUntilReady(.mac)
            }
            phase("Asking Steam to start \(g.name)")
            sendLaunch(g)
        }
        return true
    }

    /// Steam's web helper only appears once the client has finished starting.
    private func waitUntilReady(_ side: Side) async {
        for _ in 0..<90 {
            let procs = await processes()
            let ready = procs.contains { $0.contains("steam helper") || $0.contains("steamwebhelper") }
            if ready {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                Log.write("Steam looks ready")
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        Log.write("Steam readiness wait timed out")
    }

    /// Close a Steam client and make sure it is really gone: ask, ask again, then force.
    private func quitSteam(_ side: Side) async -> Bool {
        func askNicely() {
            switch side {
            case .mac:
                for app in NSRunningApplication.runningApplications(withBundleIdentifier: Config.steamBundle) { app.terminate() }
            case .windows:
                Shell.spawn(Config.cxstart, ["--bottle", Config.bottle, Config.winSteam, "-shutdown"])
            }
        }
        askNicely()
        var secs = 0
        while await steamRunning(side) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            secs += 1
            if secs == 12 {
                Log.write("\(side.rawValue) Steam still running, asking again")
                askNicely()
            }
            if secs == 25 {
                Log.write("\(side.rawValue) Steam still running, forcing it closed")
                switch side {
                case .mac:
                    for app in NSRunningApplication.runningApplications(withBundleIdentifier: Config.steamBundle) { app.forceTerminate() }
                    Shell.killProcesses(containing: ["steam helper", "steamwebhelper"])
                case .windows:
                    Shell.killProcesses(containing: ["steam.exe", "steamwebhelper.exe", "steamservice.exe"])
                }
            }
            if secs >= 40 { return !(await steamRunning(side)) }
        }
        return true
    }

    /// Ask the running Steam to start the game.
    private func sendLaunch(_ g: Game) {
        switch g.side {
        case .windows:
            Shell.spawn(Config.cxstart, ["--bottle", Config.bottle, Config.winSteam, "-applaunch", String(g.appid)])
        case .mac:
            Shell.spawn("/usr/bin/open", ["steam://rungameid/\(g.appid)"])
        }
    }

    private func startDirectly(_ g: Game) {
        guard let target = g.directTarget else { return }
        switch g.side {
        case .mac:
            Shell.spawn("/usr/bin/open", [target])
        case .windows:
            let dir = (target as NSString).deletingLastPathComponent
            Shell.spawn(Config.cxstart, ["--bottle", Config.bottle, "--workdir", dir, target])
        }
    }

    // MARK: looking at the machine

    private func processes() async -> [String] {
        await Task.detached { Shell.processes() }.value
    }

    private func gameLine(_ g: Game, in procs: [String]) -> Bool {
        let d = g.installdir.lowercased()
        let a = "steamapps/common/\(d)/"
        let b = "steamapps\\common\\\(d)\\"
        return procs.contains { $0.contains(a) || $0.contains(b) }
    }

    private func steamUp(_ side: Side, _ procs: [String]) -> Bool {
        switch side {
        case .mac: return !NSRunningApplication.runningApplications(withBundleIdentifier: Config.steamBundle).isEmpty
        case .windows: return procs.contains { $0.contains("steam.exe") }
        }
    }

    private func steamRunning(_ side: Side) async -> Bool {
        switch side {
        case .mac: return steamUp(.mac, [])
        case .windows: return steamUp(.windows, await processes())
        }
    }

    private func downloading(_ side: Side) -> Bool {
        guard let root = Config.libraryRoot(side) else { return false }
        let p = root.appendingPathComponent("steamapps/downloading").path
        return ((try? FileManager.default.contentsOfDirectory(atPath: p)) ?? []).isEmpty == false
    }
}
