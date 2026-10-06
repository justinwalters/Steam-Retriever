// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)

import SwiftUI

struct SplashView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()
            SprocketBadge(size: 300)
            Text("Steam Retriever")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Theme.text)
            HStack(spacing: 16) {
                ProgressView()
                Text(model.splashMessage)
                    .font(.title3)
                    .foregroundStyle(Theme.subtext)
            }
            Spacer()
            // Never dead-end on a spinner: Settings shows up if the check takes a moment.
            Button("Settings") { model.openSetup(at: .findMac, reason: nil) }
                .buttonStyle(RowButtonStyle())
                .fixedSize()
                .opacity(showSettings ? 1 : 0)
                .disabled(!showSettings)
                .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await AppModel.pause(seconds: 2.5)
            showSettings = true
        }
    }
}
