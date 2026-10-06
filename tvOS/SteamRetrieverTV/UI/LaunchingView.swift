// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// Play -> POST /api/launch -> poll /api/status every 2 s (up to 6 min) with Sprocket keeping you company.

import SwiftUI

struct LaunchingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if let game = model.launchGame {
                CoverImage(game: game, kind: .header)
                    .ignoresSafeArea()
                    .blur(radius: 50)
                    .opacity(0.3)
            }
            VStack(spacing: 34) {
                SprocketBadge(size: 260)
                Text(model.launchGame?.name ?? "")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(Theme.text)
                switch model.launchPhase {
                case .requesting:
                    progress("Asking the Mac\u{2026}")
                case .waiting(let what):
                    progress(what)
                case .failed(let why, let fix):
                    failure(why, fix: fix)
                }
            }
            .padding(80)
        }
        .onExitCommand { model.leaveLaunch() }
    }

    private func progress(_ text: String) -> some View {
        VStack(spacing: 26) {
            HStack(spacing: 18) {
                ProgressView()
                Text(text).font(.system(size: 32)).foregroundStyle(Theme.text)
            }
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let secs = Int(ctx.date.timeIntervalSince(model.launchStarted))
                Text("\(secs / 60):\(String(format: "%02d", secs % 60))  \u{00B7}  this can take a couple of minutes")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.subtext)
                    .monospacedDigit()
            }
            HStack(spacing: 40) {
                Button("Back to library") { model.leaveLaunch() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Settings") { model.openSetup(at: .test, reason: nil) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.top, 20)
            Text("Going back doesn't stop the game; it keeps starting on the Mac.")
                .font(.system(size: 22))
                .foregroundStyle(Theme.subtext)
        }
    }

    private func failure(_ why: String, fix: AppModel.SetupStep?) -> some View {
        VStack(spacing: 30) {
            Label(why, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.bad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 1200)
            HStack(spacing: 40) {
                Button("Retry") { model.retryLaunch() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Open Settings") { model.openSetup(at: fix ?? .test, reason: why) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Back to library") { model.leaveLaunch() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}
