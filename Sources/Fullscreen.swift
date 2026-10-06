import AppKit
import ApplicationServices

/// Makes a freshly started game fill the display, so the whole screen (what Sunshine streams) is the game.
/// Uses the Accessibility API: first the window's full-screen switch, otherwise it stretches the window
/// over the usable screen area. Needs "Accessibility" permission for Steam Retriever.
enum FullscreenFixer {
    struct Win {
        let pid: pid_t
        let bounds: CGRect
    }

    static var trusted: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func openAccessibilitySettings() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(u)
        }
    }

    /// Whole main display, in global top-left coordinates (points).
    static var screen: CGRect { CGDisplayBounds(CGMainDisplayID()) }

    /// Main display minus the menu bar and Dock, in the same top-left coordinates.
    static var usable: CGRect {
        guard let s = NSScreen.screens.first else { return screen }
        let f = s.frame, v = s.visibleFrame
        return CGRect(x: v.minX - f.minX, y: f.maxY - v.maxY, width: v.width, height: v.height)
    }

    /// Big on-screen windows (layer 0) owned by any of these processes.
    static func windows(of pids: Set<pid_t>) -> [Win] {
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return [] }
        var out: [Win] = []
        for w in list {
            guard let pid = w[kCGWindowOwnerPID as String] as? Int32, pids.contains(pid),
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let b = w[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: b as CFDictionary) else { continue }
            if rect.width < 300 || rect.height < 200 { continue }
            out.append(Win(pid: pid, bounds: rect))
        }
        return out
    }

    /// True when the window covers the display or the whole usable area.
    static func fills(_ r: CGRect) -> Bool {
        let s = screen, u = usable
        let full = r.width >= s.width - 4 && r.height >= s.height - 4
        let area = r.width >= u.width - 4 && r.height >= u.height - 4
        return full || area
    }

    private static func axSize(_ w: AXUIElement) -> CGSize {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &v) == .success, let val = v else { return .zero }
        var s = CGSize.zero
        _ = AXValueGetValue(val as! AXValue, .cgSize, &s)
        return s
    }

    /// Try to make this process's biggest window fill the screen. Returns a short description for the log.
    static func apply(pid: pid_t) -> String {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1.0)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &ref) == .success,
              let wins = ref as? [AXUIElement], !wins.isEmpty else { return "no accessible window" }
        let win = wins.max(by: { axSize($0).width * axSize($0).height < axSize($1).width * axSize($1).height }) ?? wins[0]

        var settable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(win, "AXFullScreen" as CFString, &settable) == .success, settable.boolValue {
            let r = AXUIElementSetAttributeValue(win, "AXFullScreen" as CFString, kCFBooleanTrue)
            if r == .success { return "set AXFullScreen" }
        }
        var pos = usable.origin
        var size = usable.size
        guard let pv = AXValueCreate(.cgPoint, &pos), let sv = AXValueCreate(.cgSize, &size) else { return "could not build target" }
        let a = AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, pv)
        let b = AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sv)
        let c = AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, pv)
        return "stretched window (position \(a.rawValue), size \(b.rawValue), position \(c.rawValue))"
    }
}

extension Launcher {
    /// Runs in the background once the game shows up. Gives up quietly after a few tries so it never fights the game.
    func fullscreenAfterLaunch(_ g: Game) async {
        guard UserDefaults.standard.bool(forKey: "autoFullscreen"), !Prefs.fullscreenExcluded(g.id) else { return }
        if !FullscreenFixer.trusted {
            // Show the system prompt at most once a day; after that just tell the user in the app.
            let last = UserDefaults.standard.double(forKey: "axPromptedAt")
            if Date().timeIntervalSince1970 - last > 86_400 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "axPromptedAt")
                FullscreenFixer.requestAccess()
            }
            lib.notify("Allow Steam Retriever under Privacy & Security > Accessibility so games can go full screen.")
            Log.write("fullscreen: Accessibility permission is missing")
            return
        }
        let d = g.installdir.lowercased()
        let a = "steamapps/common/\(d)/", b = "steamapps\\common\\\(d)\\"
        var applied = 0
        var settled = 0
        for _ in 0..<45 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let pids: Set<pid_t> = await Task.detached {
                var s = Set<pid_t>()
                for p in Shell.processList() where p.cmd.contains(a) || p.cmd.contains(b) { s.insert(p.pid) }
                return s
            }.value
            if pids.isEmpty { continue }
            let wins = FullscreenFixer.windows(of: pids)
            guard let big = wins.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }) else { continue }
            if FullscreenFixer.fills(big.bounds) {
                settled += 1
                if settled >= 2 {
                    Log.write("fullscreen: \(g.name) fills the screen (\(Int(big.bounds.width)) x \(Int(big.bounds.height)))")
                    return
                }
                continue
            }
            settled = 0
            if applied >= 3 {
                Log.write("fullscreen: gave up on \(g.name), window stays \(Int(big.bounds.width)) x \(Int(big.bounds.height))")
                return
            }
            applied += 1
            let how = FullscreenFixer.apply(pid: big.pid)
            Log.write("fullscreen: \(g.name) window \(Int(big.bounds.width)) x \(Int(big.bounds.height)) -> \(how)")
        }
    }
}
