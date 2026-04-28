@preconcurrency import AppKit
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
        NSApp.setActivationPolicy(.prohibited)
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
        singleInstanceCoordinator.startMonitoringDuplicateLaunches()
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
    private static let fallbackExecutableName = "Rhythm"

    private let lockPath = NSTemporaryDirectory() + "com.xiao2dou.rhythm.single-instance.lock"
    private var lockFileDescriptor: CInt = -1
    private var launchObserver: NSObjectProtocol?

    func acquireOrActivateExistingInstance() -> Bool {
        guard lockFileDescriptor == -1 else {
            return true
        }

        if activateExistingInstanceIfNeeded() {
            return false
        }

        let fileDescriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            return !activateExistingInstanceIfNeeded()
        }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(fileDescriptor)
            activateExistingInstanceIfNeeded()
            return false
        }

        if activateExistingInstanceIfNeeded() {
            flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
            return false
        }

        lockFileDescriptor = fileDescriptor
        return true
    }

    func startMonitoringDuplicateLaunches() {
        guard launchObserver == nil else {
            enforceSingleInstance()
            return
        }

        enforceSingleInstance()

        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.enforceSingleInstance()
            }
        }
    }

    deinit {
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }

        guard lockFileDescriptor >= 0 else {
            return
        }

        flock(lockFileDescriptor, LOCK_UN)
        close(lockFileDescriptor)
    }

    @discardableResult
    private func activateExistingInstanceIfNeeded() -> Bool {
        let policy = currentPolicy()
        let snapshots = NSWorkspace.shared.runningApplications.map(RunningApplicationSnapshot.init)

        guard let existing = policy.existingInstance(in: snapshots) else {
            return false
        }

        NSRunningApplication(processIdentifier: existing.processIdentifier)?
            .activate(options: [.activateIgnoringOtherApps])
        return true
    }

    private func enforceSingleInstance() {
        let policy = currentPolicy()
        let runningApplications = NSWorkspace.shared.runningApplications
        let duplicateProcessIDs = Set(
            policy
                .duplicateInstances(in: runningApplications.map(RunningApplicationSnapshot.init))
                .map(\.processIdentifier)
        )

        guard !duplicateProcessIDs.isEmpty else {
            return
        }

        for application in runningApplications where duplicateProcessIDs.contains(application.processIdentifier) {
            application.terminate()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func currentPolicy() -> SingleInstancePolicy {
        SingleInstancePolicy(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            executableName: Bundle.main.executableURL?.lastPathComponent ?? Self.fallbackExecutableName,
            processIdentifier: getpid()
        )
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
