import RhythmCore
import SwiftUI

@main
struct RhythmApp: App {
    @StateObject private var appModel = AppModel()
    @State private var isMenuBarExtraInserted = true

    private var menuBarInsertionBinding: Binding<Bool> {
        Binding(
            get: { isMenuBarExtraInserted },
            set: { newValue in
                isMenuBarExtraInserted = newValue
                guard !newValue else { return }

                // Reinsert the status item if macOS or the user removes it.
                DispatchQueue.main.async {
                    isMenuBarExtraInserted = true
                }
            }
        )
    }

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarInsertionBinding) {
            MenuBarView(
                timerEngine: appModel.timerEngine,
                settingsStore: appModel.settingsStore,
                sessionStore: appModel.sessionStore,
                launchAtLoginManager: appModel.launchAtLoginManager
            )
        } label: {
            RhythmMenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}
