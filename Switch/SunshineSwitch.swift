import AppKit
import ServiceManagement

// Menu-bar switch for the Sunshine streaming host on this Mac mini.
// Orange sun = running, red sun = running during work hours (pause it for dev), grey moon = paused.

let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") ? "/opt/homebrew/bin/brew" : "/usr/local/bin/brew"
let sunshineFormula = "lizardbyte/homebrew/sunshine"
let workDays = 2...6        // Calendar weekday: Monday = 2 ... Friday = 6
let workHours = 8..<18      // 8:00 to 17:59

@discardableResult
func run(_ path: String, _ args: [String]) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    var env = ProcessInfo.processInfo.environment
    env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
    env["HOMEBREW_NO_ENV_HINTS"] = "1"
    p.environment = env
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func switchLog(_ text: String) {
    let url = URL(fileURLWithPath: "/Volumes/STEAM/Hub/sunshine-switch.log")
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(text)\n"
    if let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile()
        h.write(Data(line.utf8))
        try? h.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

func sunshineIsRunning() -> Bool {
    run("/usr/bin/pgrep", ["-x", "sunshine"]).0 == 0
}

/// Start the Homebrew service; if the process still isn't up, kick the launch agent directly.
func resumeSunshine() -> Bool {
    let r = run(brewPath, ["services", "start", sunshineFormula])
    switchLog("brew services start -> \(r.0): \(r.1.trimmingCharacters(in: .whitespacesAndNewlines))")
    Thread.sleep(forTimeInterval: 3)
    if sunshineIsRunning() { return true }
    let uid = String(getuid())
    let plist = NSHomeDirectory() + "/Library/LaunchAgents/sh.brew.sunshine.plist"
    var k = run("/bin/launchctl", ["kickstart", "-k", "gui/\(uid)/sh.brew.sunshine"])
    switchLog("launchctl kickstart -> \(k.0): \(k.1.trimmingCharacters(in: .whitespacesAndNewlines))")
    if k.0 != 0 {
        let b = run("/bin/launchctl", ["bootstrap", "gui/\(uid)", plist])
        switchLog("launchctl bootstrap -> \(b.0): \(b.1.trimmingCharacters(in: .whitespacesAndNewlines))")
        k = run("/bin/launchctl", ["kickstart", "-k", "gui/\(uid)/sh.brew.sunshine"])
        switchLog("launchctl kickstart (2) -> \(k.0): \(k.1.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    Thread.sleep(forTimeInterval: 3)
    return sunshineIsRunning()
}

final class SwitchDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let menu = NSMenu()
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var toggleItem = NSMenuItem()
    private var loginItem = NSMenuItem()
    private var running = false
    private var working = false
    private var failed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusLine.isEnabled = false

        toggleItem = NSMenuItem(title: "Pause Sunshine", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        let web = NSMenuItem(title: "Open Sunshine Web UI", action: #selector(openWeb), keyEquivalent: "")
        web.target = self
        loginItem = NSMenuItem(title: "Start Sunshine Switch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        let quit = NSMenuItem(title: "Quit Sunshine Switch", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self

        menu.addItem(statusLine)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleItem)
        menu.addItem(web)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(loginItem)
        menu.addItem(quit)
        item.menu = menu

        render()
        refresh()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func isWorkTime() -> Bool {
        let cal = Calendar.current
        let now = Date()
        return workDays.contains(cal.component(.weekday, from: now)) && workHours.contains(cal.component(.hour, from: now))
    }

    private func refresh() {
        DispatchQueue.global().async {
            let up = run("/usr/bin/pgrep", ["-x", "sunshine"]).0 == 0
            DispatchQueue.main.async {
                self.running = up
                self.render()
            }
        }
    }

    private func render() {
        let daytime = isWorkTime()
        let symbol = running ? "sun.max.fill" : "moon.zzz.fill"
        let color: NSColor = running ? (daytime ? NSColor.systemRed : NSColor.systemOrange) : NSColor.systemGray
        let cfg = NSImage.SymbolConfiguration(paletteColors: [color])
        if let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Sunshine") {
            item.button?.image = base.withSymbolConfiguration(cfg)
        }
        var line: String
        if working { line = "Working..." }
        else if running { line = daytime ? "Sunshine is RUNNING (work hours: pause for dev?)" : "Sunshine is running" }
        else { line = "Sunshine is paused" }
        if failed { line += "  (last action failed)" }
        statusLine.title = line
        item.button?.toolTip = line
        toggleItem.title = running ? "Pause Sunshine (dev mode)" : "Resume Sunshine"
        toggleItem.isEnabled = !working
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func toggle() {
        if working { return }
        working = true
        render()
        let wantRunning = !running
        DispatchQueue.global().async {
            var ok = true
            if wantRunning {
                ok = resumeSunshine()
            } else {
                let r = run(brewPath, ["services", "stop", sunshineFormula])
                switchLog("brew services stop -> \(r.0): \(r.1.trimmingCharacters(in: .whitespacesAndNewlines))")
                // Also stop any copy started by hand or left over; wait for it to go, then force it.
                run("/usr/bin/pkill", ["-x", "sunshine"])
                var waited = 0.0
                while sunshineIsRunning() && waited < 4.0 {
                    Thread.sleep(forTimeInterval: 0.25)
                    waited += 0.25
                    if waited == 2.0 { run("/usr/bin/pkill", ["-9", "-x", "sunshine"]) }
                }
                ok = !sunshineIsRunning()
            }
            switchLog("\(wantRunning ? "resume" : "pause") finished, ok=\(ok)")
            DispatchQueue.main.async {
                self.working = false
                self.failed = !ok
                self.refresh()
            }
        }
    }

    @objc private func openWeb() {
        if let url = URL(string: "https://localhost:47990") { NSWorkspace.shared.open(url) }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { NSLog("login item change failed: \(error)") }
        render()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let switchDelegate = SwitchDelegate()
app.delegate = switchDelegate
app.run()
