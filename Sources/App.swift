import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct SteamRetrieverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var lib = Library()

    init() {
        UserDefaults.standard.register(defaults: ["quiet": true, "quitOnClose": true, "skipSteam": true])
    }

    var body: some Scene {
        WindowGroup("Steam Retriever") {
            RootView()
                .environmentObject(lib)
                .frame(minWidth: 880, minHeight: 560)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1120, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .textEditing) {
                Button("Find") { NotificationCenter.default.post(name: .focusSearch, object: nil) }
                    .keyboardShortcut("f")
            }
            CommandGroup(after: .appSettings) {
                Button("Rescan Library") { lib.rescan() }.keyboardShortcut("r")
            }
        }
    }
}
