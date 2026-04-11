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
    private var heartbeatTimer: Timer?

    init() {
        let settingsStore = SettingsStore()
        let sessionStore = SessionStore()
        let appLifecycleStore = AppLifecycleStore()
        let overlayManager = OverlayManager(settingsStore: settingsStore)
        let lockMonitor = LockMonitor()
        let launchAtLoginManager = LaunchAtLoginManager()
        let breakNotificationManager = BreakNotificationManager(settingsStore: settingsStore)

        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.appLifecycleStore = appLifecycleStore
        self.overlayManager = overlayManager
        self.launchAtLoginManager = launchAtLoginManager
        self.timerEngine = TimerEngine(
            settingsStore: settingsStore,
            sessionStore: sessionStore,
            overlayManager: overlayManager,
            lockMonitor: lockMonitor,
            breakNotifier: breakNotificationManager,
            autoStart: false
        )

        appLifecycleStore.recoverPreviousRun(at: Date(), sessionStore: sessionStore)
        timerEngine.onLifecycleStateChanged = { [weak self] in
            self?.recordLifecycleHeartbeat()
        }
        timerEngine.start()
        startHeartbeatTimer()
        runOverlaySmokeIfNeeded()
    }

    func prepareForAppTermination() {
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
