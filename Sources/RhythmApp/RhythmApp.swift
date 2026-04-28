import AppKit
import Darwin
import RhythmCore
import SwiftUI

@MainActor
final class RhythmAppDelegate: NSObject, NSApplicationDelegate {
    private let singleInstanceCoordinator: SingleInstanceCoordinator
    let isPrimaryInstance: Bool
    private var appModelStorage: AppModel?

    override init() {
        let singleInstanceCoordinator = SingleInstanceCoordinator()
        self.singleInstanceCoordinator = singleInstanceCoordinator
        self.isPrimaryInstance = singleInstanceCoordinator.acquireOrActivateExistingInstance()
        super.init()

        guard !isPrimaryInstance else { return }
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    var appModel: AppModel {
        if let appModelStorage {
            return appModelStorage
        }

        let appModel = AppModel()
        appModelStorage = appModel
        return appModel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isPrimaryInstance else {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        _ = appModel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard isPrimaryInstance else { return }
        appModelStorage?.prepareForAppTermination()
    }
}

@MainActor
private final class SingleInstanceCoordinator {
    private let lockPath = NSTemporaryDirectory() + "com.xiao2dou.rhythm.single-instance.lock"
    private var lockFileDescriptor: CInt = -1

    func acquireOrActivateExistingInstance() -> Bool {
        guard lockFileDescriptor == -1 else {
            return true
        }

        let fileDescriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return true
        }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(fileDescriptor)
            activateExistingInstance()
            return false
        }

        lockFileDescriptor = fileDescriptor
        recordCurrentProcessID(fileDescriptor)
        return true
    }

    deinit {
        guard lockFileDescriptor >= 0 else {
            return
        }

        flock(lockFileDescriptor, LOCK_UN)
        close(lockFileDescriptor)
    }

    private func recordCurrentProcessID(_ fileDescriptor: CInt) {
        let processID = "\(getpid())\n"
        ftruncate(fileDescriptor, 0)
        lseek(fileDescriptor, 0, SEEK_SET)
        _ = processID.withCString { pointer in
            write(fileDescriptor, pointer, strlen(pointer))
        }
    }

    private func activateExistingInstance() {
        let policy = SingleInstancePolicy(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            executableName: Bundle.main.executableURL?.lastPathComponent ?? "Rhythm",
            processIdentifier: getpid()
        )
        let snapshots = NSWorkspace.shared.runningApplications.map(RunningApplicationSnapshot.init)

        guard let existing = policy.existingInstance(in: snapshots) else {
            return
        }

        NSRunningApplication(processIdentifier: existing.processIdentifier)?
            .activate(options: [.activateIgnoringOtherApps])
    }
}

private extension RunningApplicationSnapshot {
    init(_ application: NSRunningApplication) {
        self.init(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            localizedName: application.localizedName,
            executableLastPathComponent: application.executableURL?.lastPathComponent
        )
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
        MenuBarExtra(isInserted: guardedMenuBarInsertionBinding) {
            if appDelegate.isPrimaryInstance {
                MenuBarView(
                    timerEngine: appDelegate.appModel.timerEngine,
                    settingsStore: appDelegate.appModel.settingsStore,
                    sessionStore: appDelegate.appModel.sessionStore,
                    launchAtLoginManager: appDelegate.appModel.launchAtLoginManager
                )
            } else {
                EmptyView()
            }
        } label: {
            if appDelegate.isPrimaryInstance {
                RhythmMenuBarLabel(
                    timerEngine: appDelegate.appModel.timerEngine,
                    settingsStore: appDelegate.appModel.settingsStore
                )
            } else {
                EmptyView()
            }
        }
        .menuBarExtraStyle(.window)

        Window("Rhythm", id: RhythmWindowID.insights.rawValue) {
            if appDelegate.isPrimaryInstance {
                InsightsView(
                    timerEngine: appDelegate.appModel.timerEngine,
                    settingsStore: appDelegate.appModel.settingsStore,
                    sessionStore: appDelegate.appModel.sessionStore
                )
                .frame(minWidth: 860, minHeight: 760)
            } else {
                EmptyView()
            }
        }
    }

    private var guardedMenuBarInsertionBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.isPrimaryInstance && isMenuBarExtraInserted },
            set: { menuBarInsertionBinding.wrappedValue = $0 }
        )
    }
}
