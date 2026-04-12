import AppKit
import Foundation
import RhythmCore

@MainActor
final class AppModel: ObservableObject {
    let settingsStore: SettingsStore
    let sessionStore: SessionStore
    let timerEngine: TimerEngine
    let overlayManager: OverlayManager
    let launchAtLoginManager: LaunchAtLoginManager

    private let appLifecycleStore: AppLifecycleStore
    private let lockMonitor: LockMonitor
    private let sleepWakeMonitor: SleepWakeMonitor
    private var heartbeatTimer: Timer?
    private var wakeResolutionWorkItem: DispatchWorkItem?

    init() {
        let settingsStore = SettingsStore()
        let sessionStore = SessionStore()
        let appLifecycleStore = AppLifecycleStore()
        let overlayManager = OverlayManager(settingsStore: settingsStore)
        let lockMonitor = LockMonitor()
        let sleepWakeMonitor = SleepWakeMonitor()
        let launchAtLoginManager = LaunchAtLoginManager()
        let breakNotificationManager = BreakNotificationManager(settingsStore: settingsStore)

        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.appLifecycleStore = appLifecycleStore
        self.overlayManager = overlayManager
        self.lockMonitor = lockMonitor
        self.sleepWakeMonitor = sleepWakeMonitor
        self.launchAtLoginManager = launchAtLoginManager
        self.timerEngine = TimerEngine(
            settingsStore: settingsStore,
            sessionStore: sessionStore,
            overlayManager: overlayManager,
            lockMonitor: lockMonitor,
            systemSleepMonitor: sleepWakeMonitor,
            breakNotifier: breakNotificationManager,
            autoStart: false
        )

        appLifecycleStore.recoverPreviousRun(at: Date(), sessionStore: sessionStore)
        timerEngine.onLifecycleStateChanged = { [weak self] in
            self?.recordLifecycleHeartbeat()
        }
        sleepWakeMonitor.onDidWake = { [weak self] in
            self?.resolveWakeState()
        }
        timerEngine.start()
        startHeartbeatTimer()
        runOverlaySmokeIfNeeded()
    }

    func prepareForAppTermination() {
        wakeResolutionWorkItem?.cancel()
        wakeResolutionWorkItem = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        let now = Date()
        timerEngine.prepareForAppExit(at: now)
        appLifecycleStore.recordCleanExit(at: now)
    }

    private func startHeartbeatTimer() {
        let timer = Timer(timeInterval: TimeInterval(AppLifecycleStore.heartbeatIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordLifecycleHeartbeat()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer
    }

    private func recordLifecycleHeartbeat() {
        appLifecycleStore.recordHeartbeat(at: Date(), snapshot: timerEngine.lifecycleSnapshot)
    }

    private func resolveWakeState() {
        wakeResolutionWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.timerEngine.handleSystemDidWake(isScreenLocked: self.lockMonitor.isScreenLocked)
        }

        wakeResolutionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func runOverlaySmokeIfNeeded() {
        guard ProcessInfo.processInfo.environment["RHYTHM_SMOKE_OVERLAY"] == "1" else {
            return
        }

        print("[RhythmSmoke] start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            print("[RhythmSmoke] trigger break")
            self.timerEngine.startBreakNow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self else { return }
            print("[RhythmSmoke] force skip")
            self.timerEngine.skipBreak()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            print("[RhythmSmoke] end")
            NSApplication.shared.terminate(nil)
        }
    }
}
