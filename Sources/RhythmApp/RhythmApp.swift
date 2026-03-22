import RhythmCore
import SwiftUI

@main
struct RhythmApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("Rhythm", systemImage: "waveform.path.ecg.circle.fill") {
            MenuBarView(
                timerEngine: appModel.timerEngine,
                settingsStore: appModel.settingsStore,
                sessionStore: appModel.sessionStore
            )
        }
        .menuBarExtraStyle(.window)
    }
}
