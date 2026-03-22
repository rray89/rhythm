import RhythmCore
import SwiftUI

@main
struct RhythmApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("Rhythm", systemImage: "metronome") {
            MenuBarView(
                timerEngine: appModel.timerEngine,
                settingsStore: appModel.settingsStore,
                sessionStore: appModel.sessionStore
            )
        }
        .menuBarExtraStyle(.window)
    }
}
