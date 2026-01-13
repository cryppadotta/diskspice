import SwiftUI

@main
struct DiskSpiceApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)

        Settings {
            PreferencesView(appState: appState)
        }
    }
}
