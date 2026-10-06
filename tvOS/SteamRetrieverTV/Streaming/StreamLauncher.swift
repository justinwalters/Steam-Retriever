// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// The seam between our UI and Moonlight. The UI only ever talks to this protocol.
//
// Phase 0 (now): PreviewStreamLauncher, a stand-in that shows a placeholder "stream".
// Phase 3: MoonlightStreamLauncher, built inside the moonlight-ios fork's tvOS target,
//          wraps PairManager (Sunshine PIN pairing) and StreamFrameViewController
//          streaming Sunshine's "Desktop" app. See tvOS/PLAN.md.

import SwiftUI

enum SunshinePairing: Equatable {
    case paired
    case notPaired
    case unreachable(String)
    case unavailable(String)   // no streaming engine in this build
}

enum StreamEnd: Equatable {
    case userQuit
    case failed(String)
}

@MainActor
protocol StreamLauncher: AnyObject {
    /// Short name for Settings and logs ("Moonlight", "Preview").
    var engineName: String { get }

    /// Is this Apple TV paired with Sunshine on that host?
    func sunshinePairing(host: String) async -> SunshinePairing

    /// Runs Moonlight's pairing; `showPIN` is called with the 4-digit PIN to show large on screen
    /// while the user types it into Sunshine's web UI on the Mac.
    func pairSunshine(host: String, showPIN: @escaping @MainActor (String) -> Void) async throws

    /// Full-screen view that streams Sunshine's "Desktop" app and calls `onEnd` when the stream stops.
    func streamView(host: String, onEnd: @escaping @MainActor (StreamEnd) -> Void) -> AnyView
}

/// Stand-in until Moonlight is wired in. Lets the whole browse, launch and poll flow run in the simulator.
@MainActor
final class PreviewStreamLauncher: StreamLauncher {
    let engineName = "Preview (no streaming yet)"

    func sunshinePairing(host: String) async -> SunshinePairing {
        .unavailable("Streaming arrives when Moonlight is added (phase 3).")
    }

    func pairSunshine(host: String, showPIN: @escaping @MainActor (String) -> Void) async throws {
        showPIN("1234")
        try await Task.sleep(nanoseconds: 3_000_000_000)
    }

    func streamView(host: String, onEnd: @escaping @MainActor (StreamEnd) -> Void) -> AnyView {
        AnyView(PreviewStreamView(host: host, onEnd: onEnd))
    }
}

private struct PreviewStreamView: View {
    let host: String
    let onEnd: @MainActor (StreamEnd) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Image(systemName: "play.tv")
                    .font(.system(size: 120, weight: .light))
                    .foregroundStyle(Theme.highlight)
                Text("The stream from \(host) would start here")
                    .font(.title2)
                    .foregroundStyle(Theme.text)
                Text("Moonlight isn't in this build yet. The game is running on the Mac.")
                    .foregroundStyle(Theme.subtext)
                Button("Return to library") { onEnd(.userQuit) }
                    .padding(.top, 20)
            }
        }
        .onExitCommand { onEnd(.userQuit) }
    }
}
