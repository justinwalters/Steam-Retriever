// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)

import SwiftUI

@main
struct SteamRetrieverTVApp: App {
    @State private var model = AppModel(streamer: PreviewStreamLauncher())

    init() {
        // Covers come back with Cache-Control: max-age=3600; give AsyncImage room to keep them.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 256 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .task { await model.start() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch model.screen {
            case .splash: SplashView()
            case .setup: SetupView()
            case .home: HomeView()
            case .launching: LaunchingView()
            case .streaming:
                if let host = model.streamHost {
                    model.streamer.streamView(host: host) { end in model.streamEnded(end) }
                        .ignoresSafeArea()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
    }
}
