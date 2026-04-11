import AppKit
import RhythmCore
import SwiftUI

@MainActor
final class RhythmAppDelegate: NSObject, NSApplicationDelegate {
    let appModel = AppModel()

    func applicationWillTerminate(_ notification: Notification) {
        appModel.prepareForAppTermination()
    }
}

@main
struct RhythmApp: App {
    @NSApplicationDelegateAdaptor(RhythmAppDelegate.self) private var appDelegate
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
                timerEngine: appDelegate.appModel.timerEngine,
                settingsStore: appDelegate.appModel.settingsStore,
                sessionStore: appDelegate.appModel.sessionStore,
                launchAtLoginManager: appDelegate.appModel.launchAtLoginManager
            )
        } label: {
            RhythmMenuBarLabel(
                timerEngine: appDelegate.appModel.timerEngine,
                settingsStore: appDelegate.appModel.settingsStore
            )
        }
        .menuBarExtraStyle(.window)
    }
}
