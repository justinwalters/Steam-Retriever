// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// "Steam Retriever Big Picture": side nav, hero banner for the focused game, shelves.

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            // The game page replaces the browser rather than overlaying it, so focus can't
            // wander onto tiles hidden underneath.
            if let game = model.detailGame {
                GamePage(game: game)
                    .transition(.opacity)
            } else {
                HStack(spacing: 0) {
                    SideNav()
                    VStack(spacing: 0) {
                        Banners()
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.detailGame)
    }

    @ViewBuilder private var content: some View {
        if let error = model.libraryError, model.games.isEmpty {
            LibraryErrorView(message: error)
        } else if model.games.isEmpty {
            VStack(spacing: 20) {
                ProgressView()
                Text("Loading your library\u{2026}").foregroundStyle(Theme.subtext)
            }
        } else {
            switch model.navSection {
            case .home: HomeShelves()
            case .library: GameGrid(title: "Library", games: model.allGames)
            case .mac: GameGrid(title: "Mac games", games: model.games(for: .mac))
            case .windows: GameGrid(title: "Windows games", games: model.games(for: .windows))
            case .search: SearchSection()
            case .nowPlaying: NowPlayingSection()
            case .settings: HomeShelves()   // Settings opens the Setup screen instead
            }
        }
    }
}

// MARK: - side nav

private struct SideNav: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                SprocketBadge(size: 72)
                Text("Steam Retriever")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
            }
            .padding(.bottom, 36)

            ForEach(AppModel.NavSection.allCases) { section in
                Button {
                    if section == .settings {
                        model.openSetup(at: .findMac, reason: nil)
                    } else {
                        model.navSection = section
                    }
                } label: {
                    Label(section.title, systemImage: section.symbol)
                }
                .buttonStyle(RowButtonStyle(selected: model.navSection == section))
            }
            Spacer()
            if let host = model.host {
                Text(host.serviceName ?? host.address)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.subtext)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 30)
        .frame(width: Theme.navWidth)
        .frame(maxHeight: .infinity)
        .background(Theme.panel.ignoresSafeArea())
        .focusSection()
    }
}

// MARK: - banners

private struct Banners: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.sunshinePaused {
                bar(symbol: "pause.circle.fill",
                    text: "Sunshine is paused on the Mac. You can browse, but Play is off until it's back on (Sunshine Switch on the Mac).",
                    color: Theme.brass)
            }
            if let notice = model.notice {
                bar(symbol: "exclamationmark.triangle.fill", text: notice, color: Theme.bad)
                    .task {
                        await AppModel.pause(seconds: 8)
                        model.notice = nil
                    }
            }
        }
    }

    private func bar(symbol: String, text: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).foregroundStyle(Theme.text)
            Spacer()
        }
        .font(.system(size: 26))
        .padding(.horizontal, 50)
        .padding(.vertical, 18)
        .background(color.opacity(0.18))
    }
}

private struct LibraryErrorView: View {
    @Environment(AppModel.self) private var model
    let message: String

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 80)).foregroundStyle(Theme.bad)
            Text(message).font(.title3).foregroundStyle(Theme.text).multilineTextAlignment(.center).frame(maxWidth: 1000)
            HStack(spacing: 40) {
                Button("Retry") { Task { await model.refreshLibrary() } }.buttonStyle(PrimaryButtonStyle())
                Button("Settings") { model.openSetup(at: .findMac, reason: message) }.buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - home shelves + hero

private struct HomeShelves: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focus: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if let game = model.focusedGame {
                    HeroBanner(game: game)
                }
                if !model.continueGames.isEmpty {
                    Shelf(title: "Continue", games: model.continueGames, focus: $focus)
                }
                Shelf(title: "Recently added", games: model.recentGames, focus: $focus)
                Shelf(title: "All Games", games: model.allGames, focus: $focus)
            }
            .padding(.horizontal, 50)
            .padding(.bottom, 60)
        }
        .onChange(of: focus) { _, key in
            // Keys look like "Shelf title|game-id"; the hero follows whatever tile has focus.
            if let id = key?.split(separator: "|").last.map(String.init) { model.focusedGameID = id }
        }
    }
}

struct HeroBanner: View {
    @Environment(AppModel.self) private var model
    let game: Game

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CoverImage(game: game, kind: .header)
                .frame(height: 440)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(colors: [Theme.background.opacity(0.0), Theme.background.opacity(0.95)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    LinearGradient(colors: [Theme.background.opacity(0.9), .clear],
                                   startPoint: .leading, endPoint: .center)
                )
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 18) {
                    Text(game.name)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    EnvBadge(env: game.env)
                }
                if !metaLine.isEmpty {
                    Text(metaLine).font(.system(size: 24)).foregroundStyle(Theme.subtext)
                }
                Text(game.shortDescription.isEmpty ? " " : game.shortDescription)
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.text.opacity(0.9))
                    .lineLimit(2)
                    .frame(maxWidth: 1100, alignment: .leading)
                PlayButton(game: game)
                    .padding(.top, 8)
            }
            .padding(36)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 40)
        .focusSection()
        .animation(.easeInOut(duration: 0.2), value: game.id)
    }

    private var metaLine: String {
        ([game.developer] + [game.genres.prefix(3).joined(separator: ", ")])
            .filter { !$0.isEmpty }
            .joined(separator: "  \u{00B7}  ")
    }
}

struct PlayButton: View {
    @Environment(AppModel.self) private var model
    let game: Game

    var body: some View {
        HStack(spacing: 24) {
            Button {
                model.play(game)
            } label: {
                Label(model.status?.playing == game.id ? "Resume" : "Play", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.sunshinePaused)
            if model.sunshinePaused {
                Text("Sunshine is paused on the Mac")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.brass)
            }
        }
    }
}

// MARK: - grids, search, now playing

struct GameGrid: View {
    let title: String
    let games: [Game]
    private let columns = Array(repeating: GridItem(.fixed(Theme.posterSize.width), spacing: 48), count: 5)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 50)
                if games.isEmpty {
                    Text("Nothing here yet.").foregroundStyle(Theme.subtext)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 56) {
                    ForEach(games) { GameTile(game: $0) }
                }
                .padding(.vertical, 30)
            }
            .padding(.horizontal, 60)
        }
    }
}

private struct SearchSection: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    private var results: [Game] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.allGames }
        return model.allGames.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.developer.localizedCaseInsensitiveContains(q)
                || $0.genres.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        // .searchable gives the tvOS keyboard and dictation for free.
        NavigationStack {
            GameGrid(title: query.isEmpty ? "All games" : "Results", games: results)
                .searchable(text: $query, prompt: "Games, developers, genres")
        }
    }
}

private struct NowPlayingSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Now Playing")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.text)
            if let game = model.playingGame {
                HeroBanner(game: game)
            } else {
                Text("Nothing is running on the Mac.")
                    .font(.title3)
                    .foregroundStyle(Theme.subtext)
                if let secs = model.status?.steamClosesInSeconds {
                    Text("Steam closes in \(secs / 60) min \(secs % 60) s if nothing starts.")
                        .foregroundStyle(Theme.subtext)
                }
            }
            Spacer()
        }
        .padding(60)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - game page (Select on a tile)

private struct GamePage: View {
    @Environment(AppModel.self) private var model
    let game: Game

    private var current: Game { model.games.first { $0.id == game.id } ?? game }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            CoverImage(game: current, kind: .header)
                .ignoresSafeArea()
                .blur(radius: 40)
                .opacity(0.35)
            HStack(alignment: .top, spacing: 70) {
                CoverImage(game: current, kind: .poster)
                    .frame(width: 400, height: 600)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(radius: 30)
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 20) {
                        Text(current.name).font(.system(size: 64, weight: .bold)).foregroundStyle(Theme.text)
                        EnvBadge(env: current.env)
                    }
                    facts
                    Text(current.description.isEmpty ? "No description yet. The Mac fetches it the first time." : current.description)
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.text.opacity(0.9))
                        .frame(maxWidth: 1000, alignment: .leading)
                    PlayButton(game: current)
                        .padding(.top, 20)
                    Spacer()
                }
            }
            .padding(90)
        }
        .onExitCommand { model.detailGame = nil }
    }

    private var facts: some View {
        let size = current.sizeBytes > 0 ? ByteCountFormatter.string(fromByteCount: current.sizeBytes, countStyle: .file) : ""
        let items = [current.developer, current.released, current.genres.joined(separator: ", "), size].filter { !$0.isEmpty }
        return Text(items.joined(separator: "  \u{00B7}  "))
            .font(.system(size: 26))
            .foregroundStyle(Theme.subtext)
    }
}
