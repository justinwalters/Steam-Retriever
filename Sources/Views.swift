import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}

enum Theme {
    static let bgTop = Color(hex: "0A0D13")
    static let bgBottom = Color(hex: "131A2A")
    static let card = Color(hex: "161B26")
    static let cardHover = Color(hex: "1D2433")
    static let accent = Color(hex: "4C8DFF")
    static let mac = Color(hex: "6AA9FF")
    static let win = Color(hex: "F0A35E")
    static let green = Color(hex: "5EC98A")
    static let muted = Color(hex: "8FA3C7")
}

extension Notification.Name {
    static let focusSearch = Notification.Name("SteamRetrieverFocusSearch")
}

// MARK: - window chrome
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.styleMask.insert(.fullSizeContentView)
            w.isMovableByWindowBackground = true
            w.backgroundColor = NSColor(red: 10 / 255, green: 13 / 255, blue: 19 / 255, alpha: 1)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - root
struct RootView: View {
    @EnvironmentObject var lib: Library
    @StateObject private var ui = UIState()
    private var query: String { ui.query }
    private var filter: LibFilter { ui.filter }

    private var filtered: [Game] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return lib.games.filter { g in
            switch filter {
            case .all: break
            case .mac: if g.side != .mac { return false }
            case .windows: if g.side != .windows { return false }
            }
            if q.isEmpty { return true }
            if g.name.lowercased().contains(q) { return true }
            if let m = lib.meta[g.appid] {
                return m.developer.lowercased().contains(q)
                    || m.genres.contains { $0.lowercased().contains(q) }
                    || m.description.lowercased().contains(q)
            }
            return false
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                ZStack {
                    content
                    if let g = lib.splashGame {
                        SplashView(game: g).transition(.opacity)
                    }
                }
            }
            if let n = lib.notice {
                VStack {
                    Spacer()
                    Text(n)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(Color(hex: "232B3D")))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                        .padding(.bottom, 22)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: lib.notice)
        .animation(.easeOut(duration: 0.25), value: lib.splashGame)
        .background(WindowConfigurator())
    }

    private var subtitle: String {
        if let code = lib.pairingCode {
            return "Apple TV pairing code  " + String(code.prefix(3)) + " " + String(code.suffix(3))
        }
        let games = "\(filtered.count) \(filtered.count == 1 ? "game" : "games")"
        guard let left = lib.idleLeft, left > 0 else { return games }
        return games + "  \u{00B7}  Steam closes in \(left / 60):" + String(format: "%02d", left % 60)
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Steam Retriever").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            SearchField(text: $ui.query, placeholder: "Search games, genres, developers")
                .frame(height: 28)
                .frame(maxWidth: 420)

            Picker("", selection: $ui.filter) {
                ForEach(LibFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 210)

            Spacer(minLength: 0)
            SettingsMenu()
        }
        .padding(.leading, 86).padding(.trailing, 22)
        .frame(height: 58)
    }

    @ViewBuilder private var content: some View {
        let macMissing = lib.found[.mac] == false
        let winMissing = lib.found[.windows] == false
        if macMissing && winMissing && lib.games.isEmpty {
            Empty(icon: "externaldrive.badge.exclamationmark", title: "STEAM drive not found",
                  text: "Connect the STEAM drive and your games will appear here.")
        } else if lib.loaded && lib.games.isEmpty {
            Empty(icon: "gamecontroller", title: "No games installed yet",
                  text: "Download a game in either Steam and it shows up here automatically.")
        } else {
            VStack(spacing: 0) {
                if macMissing || winMissing {
                    Text("\(macMissing ? "Mac" : "CrossOver") library not found. Showing the last known games.")
                        .font(.system(size: 12)).foregroundStyle(Color(hex: "E5B94E"))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(Color(hex: "2A2417"))
                }
                if filtered.isEmpty && !lib.games.isEmpty {
                    Empty(icon: "magnifyingglass", title: "No matches", text: "Nothing matches \u{201C}\(query)\u{201D}.")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 410, maximum: 560), spacing: 18)], spacing: 18) {
                            ForEach(filtered) { g in GameCard(game: g) }
                        }
                        .padding(24)
                    }
                }
            }
        }
    }
}

struct Empty: View {
    let icon: String, title: String, text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 38, weight: .light)).foregroundStyle(Theme.muted)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsMenu: View {
    @EnvironmentObject var lib: Library
    @AppStorage("quiet") private var quiet = true
    @AppStorage("quitOnClose") private var quitOnClose = true
    @AppStorage("skipSteam") private var skipSteam = true
    @AppStorage("apiEnabled") private var apiEnabled = true
    @AppStorage("autoFullscreen") private var autoFullscreen = true

    var body: some View {
        Menu {
            Toggle("Start Steam quietly (no windows)", isOn: $quiet)
            Toggle("Close Steam after 5 minutes idle", isOn: $quitOnClose)
            Toggle("Skip Steam for games that don\u{2019}t need it", isOn: $skipSteam)
            Divider()
            Text(FullscreenFixer.trusted ? "Full screen control: allowed" : "Full screen control: NOT allowed yet")
            Toggle("Go full screen after launching a game", isOn: $autoFullscreen)
            Button("Allow full screen control\u{2026}") { FullscreenFixer.requestAccess(); FullscreenFixer.openAccessibilitySettings() }
            Divider()
            Toggle("Allow Apple TV to connect", isOn: Binding(get: { apiEnabled }, set: { apiEnabled = $0; lib.setAPI($0) }))
            Button("Pair Apple TV\u{2026}") { lib.beginPairing() }
            Divider()
            Button("Rescan library") { lib.rescan() }
            Button("Show STEAM drive in Finder") {
                if let v = Config.volumeRoots().first { NSWorkspace.shared.open(v) }
            }
        } label: {
            Image(systemName: "gearshape").font(.system(size: 14)).foregroundStyle(Theme.muted)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }
}

// MARK: - card
struct GameCard: View {
    let game: Game
    @EnvironmentObject var lib: Library
    @StateObject private var hoverState = Flag()
    private var hover: Bool { hoverState.on }

    private var meta: Meta? { lib.meta[game.appid] }
    private var status: String? { lib.status[game.id] }
    private var sideColor: Color { game.side == .mac ? Theme.mac : Theme.win }

    private var subtitle: String? {
        guard let m = meta else { return nil }
        var parts: [String] = []
        if !m.developer.isEmpty { parts.append(m.developer) }
        if !m.genres.isEmpty { parts.append(m.genres.prefix(3).joined(separator: ", ")) }
        return parts.isEmpty ? nil : parts.joined(separator: "  \u{00B7}  ")
    }

    private var blurb: String {
        guard let m = meta else { return "Loading details\u{2026}" }
        return m.description.isEmpty ? "No description available." : m.shortDescription
    }

    var body: some View {
        Button { lib.play(game) } label: {
            HStack(spacing: 0) {
                Poster(appid: game.appid).frame(width: 133, height: 200)
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                    if let s = subtitle {
                        Text(s).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Text(blurb).font(.system(size: 12.5)).foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(4).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    HStack(spacing: 7) {
                        Tag(text: game.side.label, color: sideColor)
                        if game.needsSteam == false { Tag(text: "No Steam needed", color: Theme.green) }
                        Text(ByteCountFormatter.string(fromByteCount: game.size, countStyle: .file))
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        Spacer(minLength: 4)
                        action
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(hover ? Theme.cardHover : Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(hover ? 0.18 : 0.07), lineWidth: 1))
            .shadow(color: .black.opacity(hover ? 0.5 : 0.25), radius: hover ? 18 : 8, y: hover ? 8 : 3)
            .scaleEffect(hover ? 1.012 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hoverState.on = $0 }
        .animation(.easeOut(duration: 0.14), value: hover)
        .task { lib.ensureMeta(game.appid) }
        .contextMenu {
            Button("Play") { lib.play(game) }
            if game.directTarget != nil && game.needsSteam == false {
                Button("Play with Steam") { lib.play(game, mode: .steam) }
            }
            if game.directTarget != nil && game.needsSteam != false {
                Button("Try without Steam") { lib.play(game, mode: .direct) }
            }
            Divider()
            Button(Prefs.fullscreenExcluded(game.id) ? "Allow auto full screen for this game" : "Don\u{2019}t auto full screen this game") {
                Prefs.toggleFullscreenExclusion(game.id)
            }
            Button("Show in Finder") { lib.showInFinder(game) }
            Button("Open Steam store page") { lib.openStorePage(game) }
        }
    }

    @ViewBuilder private var action: some View {
        if let s = status {
            HStack(spacing: 6) {
                if s == "Playing" {
                    Circle().fill(Theme.green).frame(width: 8, height: 8)
                } else {
                    ProgressView().controlSize(.small)
                }
                Text(s).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(s == "Playing" ? Theme.green : Color.white.opacity(0.85))
        } else {
            HStack(spacing: 5) {
                Image(systemName: "play.fill").font(.system(size: 10))
                Text("Play").font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 13).padding(.vertical, 6)
            .background(Capsule().fill(hover ? Theme.accent : Theme.accent.opacity(0.2)))
            .foregroundStyle(hover ? Color.white : Theme.accent)
        }
    }
}

struct Tag: View {
    let text: String, color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.16)))
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
            .foregroundStyle(color)
    }
}

struct Poster: View {
    let appid: Int
    @StateObject private var model = PosterModel()
    private let w: CGFloat = 133
    private let h: CGFloat = 200

    var body: some View {
        Color.clear
            .overlay(
                ZStack {
                    LinearGradient(colors: [Color(hex: "1F2840"), Color(hex: "121828")], startPoint: .top, endPoint: .bottom)
                    if let p = model.poster {
                        Image(nsImage: p).resizable().scaledToFill()
                    } else if let img = model.header {
                        // Wide art: blurred copy fills the poster, sharp copy sits centred at full width.
                        Image(nsImage: img).resizable().scaledToFill().blur(radius: 18).opacity(0.8)
                        Image(nsImage: img).resizable().scaledToFit().frame(width: w)
                    } else {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 28)).foregroundStyle(Color.white.opacity(0.15))
                    }
                }
            )
            .frame(width: w, height: h)
            .clipped()
            .task(id: appid) {
                if model.poster == nil && model.header == nil {
                    model.poster = await Remote.image(appid, .poster)
                    if model.poster == nil { model.poster = await Remote.apiPoster(appid) }
                    if model.poster == nil {
                        model.header = await Remote.image(appid, .header)
                        if model.header == nil { model.header = await Remote.storeImage(appid) }
                    }
                }
            }
    }
}

// MARK: - small observable helpers (plain ObservableObject: no SwiftUI macros needed)
enum LibFilter: String, CaseIterable { case all = "All", mac = "Mac", windows = "Windows" }

final class UIState: ObservableObject {
    @Published var query = ""
    @Published var filter: LibFilter = .all
}

final class Flag: ObservableObject {
    @Published var on = false
}

final class PosterModel: ObservableObject {
    @Published var poster: NSImage?
    @Published var header: NSImage?
}

/// Native search field; Cmd+F focuses it.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        var token: NSObjectProtocol?
        init(_ p: SearchField) { parent = p }
        func controlTextDidChange(_ n: Notification) {
            if let f = n.object as? NSSearchField { parent.text = f.stringValue }
        }
        deinit { if let t = token { NotificationCenter.default.removeObserver(t) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let f = NSSearchField()
        f.placeholderString = placeholder
        f.delegate = context.coordinator
        f.font = NSFont.systemFont(ofSize: 13.5)
        f.focusRingType = .none
        context.coordinator.token = NotificationCenter.default.addObserver(
            forName: .focusSearch, object: nil, queue: .main) { [weak f] _ in
            f?.window?.makeFirstResponder(f)
        }
        return f
    }

    func updateNSView(_ f: NSSearchField, context: Context) {
        if f.stringValue != text { f.stringValue = text }
        context.coordinator.parent = self
    }
}
