// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)

import SwiftUI

/// Cover art from GET /api/games/{id}/cover, with the game name as a fallback while it loads.
struct CoverImage: View {
    @Environment(AppModel.self) private var model
    let game: Game
    var kind: CoverKind = .poster

    var body: some View {
        AsyncImage(url: model.api?.coverURL(game.id, kind: kind), transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    LinearGradient(colors: [Theme.accent, Theme.panel], startPoint: .top, endPoint: .bottom)
                    Text(game.name)
                        .font(.system(size: kind == .poster ? 26 : 34, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.text)
                        .padding(18)
                }
            }
        }
    }
}

/// A poster tile on a shelf or in the library grid.
struct GameTile: View {
    @Environment(AppModel.self) private var model
    let game: Game

    var body: some View {
        Button {
            model.detailGame = game        // Select opens the game page; Play lives there
        } label: {
            ZStack(alignment: .topTrailing) {
                CoverImage(game: game, kind: .poster)
                    .frame(width: Theme.posterSize.width, height: Theme.posterSize.height)
                if model.status?.playing == game.id {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.highlight)
                        .padding(10)
                }
            }
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel("\(game.name), \(game.env.label)")
    }
}

/// A titled horizontal row of tiles. Focus moving across it drives the hero banner.
struct Shelf: View {
    @Environment(AppModel.self) private var model
    let title: String
    let games: [Game]
    var focus: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.subtext)
                .padding(.leading, 6)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(games) { game in
                        GameTile(game: game)
                            .focused(focus, equals: "\(title)|\(game.id)")
                    }
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
            }
        }
    }
}
