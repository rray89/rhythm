import Foundation

public enum RhythmMode: Equatable {
    case focusing
    case resting
}

@MainActor
public protocol RestSessionStoring: AnyObject {
    func add(_ session: RestSession)
}

@MainActor
public protocol RestOverlaying: AnyObject {
    var onSkipped: (() -> Void)? { get set }
    var onCompleted: (() -> Void)? { get set }
    func present(restSeconds: Int)
    func extendRest(by seconds: Int)
    func dismiss()
    func skipByEscape()
}

@MainActor
public protocol ScreenLockMonitoring: AnyObject {
    var onScreenLocked: (() -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
public final class TimerEngine: ObservableObject {
    @Published public private(set) var mode: RhythmMode = .focusing
    @Published public private(set) var secondsUntilBreak: Int

    private let settingsStore: RhythmSettings
    private let sessionStore: RestSessionStoring
    private let overlayManager: RestOverlaying
    private let lockMonitor: ScreenLockMonitoring
    private let nowProvider: () -> Date
    private let useSystemTimer: Bool

    private var cycleStartedAt = Date()
    private var restStartedAt: Date?
    private var currentFocusTargetSeconds: Int
    private var currentRestTargetSeconds: Int?
    private var timer: Timer?

    public init(
        settingsStore: RhythmSettings,
        sessionStore: RestSessionStoring,
        overlayManager: RestOverlaying,
        lockMonitor: ScreenLockMonitoring,
        nowProvider: @escaping () -> Date = Date.init,
        autoStart: Bool = true,
        useSystemTimer: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.overlayManager = overlayManager
        self.lockMonitor = lockMonitor
        self.nowProvider = nowProvider
        self.useSystemTimer = useSystemTimer
        self.currentFocusTargetSeconds = settingsStore.focusSeconds
        self.secondsUntilBreak = settingsStore.focusSeconds

        overlayManager.onSkipped = { [weak self] in
            self?.finishRest(skipped: true, skipReason: "esc")
        }

        overlayManager.onCompleted = { [weak self] in
            self?.finishRest(skipped: false, skipReason: nil)
        }

        lockMonitor.onScreenLocked = { [weak self] in
            self?.handleScreenLocked()
        }

        if autoStart {
            start()
        }
    }

    public func start() {
        timer?.invalidate()
        cycleStartedAt = nowProvider()
        currentFocusTargetSeconds = settingsStore.focusSeconds
        currentRestTargetSeconds = nil
        secondsUntilBreak = currentFocusTargetSeconds
        mode = .focusing
        lockMonitor.start()

        if useSystemTimer {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.processTick(now: self.nowProvider())
                }
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
    }

    public func resetCycle() {
        overlayManager.dismiss()
        restStartedAt = nil
        currentFocusTargetSeconds = settingsStore.focusSeconds
        currentRestTargetSeconds = nil
        cycleStartedAt = nowProvider()
        mode = .focusing
        secondsUntilBreak = currentFocusTargetSeconds
    }

    public func startBreakNow() {
        guard mode == .focusing else { return }
        beginResting()
    }

    public func skipBreak() {
        guard mode == .resting else { return }
        overlayManager.skipByEscape()
    }

    public func extendFocus(by seconds: Int) {
        guard mode == .focusing, seconds > 0 else { return }
        currentFocusTargetSeconds += seconds
        processTick(now: nowProvider())
    }

    public func extendRest(by seconds: Int) {
        guard mode == .resting, seconds > 0 else { return }
        currentRestTargetSeconds = (currentRestTargetSeconds ?? settingsStore.restSeconds) + seconds
        overlayManager.extendRest(by: seconds)
    }

    public func processTick(now: Date) {
        guard mode == .focusing else { return }

        let elapsed = Int(now.timeIntervalSince(cycleStartedAt))
        let remaining = max(0, currentFocusTargetSeconds - elapsed)
        secondsUntilBreak = remaining

        if remaining == 0 {
            beginResting()
        }
    }

    private func beginResting() {
        if settingsStore.skipRestEnabled {
            let now = nowProvider()
            let session = RestSession(
                scheduledRestSeconds: settingsStore.restSeconds,
                actualRestSeconds: 0,
                startedAt: now,
                endedAt: now,
                skipped: true,
                skipReason: "no_rest"
            )
            sessionStore.add(session)
            currentRestTargetSeconds = nil
            cycleStartedAt = now
            currentFocusTargetSeconds = settingsStore.focusSeconds
            mode = .focusing
            secondsUntilBreak = currentFocusTargetSeconds
            return
        }

        mode = .resting
        restStartedAt = nowProvider()
        currentRestTargetSeconds = settingsStore.restSeconds
        overlayManager.present(restSeconds: currentRestTargetSeconds ?? settingsStore.restSeconds)
    }

    private func finishRest(skipped: Bool, skipReason: String?) {
        guard mode == .resting, let restStartedAt else { return }

        let endedAt = nowProvider()
        let actualSeconds = max(0, Int(endedAt.timeIntervalSince(restStartedAt)))
        let session = RestSession(
            scheduledRestSeconds: currentRestTargetSeconds ?? settingsStore.restSeconds,
            actualRestSeconds: actualSeconds,
            startedAt: restStartedAt,
            endedAt: endedAt,
            skipped: skipped,
            skipReason: skipReason
        )
        sessionStore.add(session)
        self.restStartedAt = nil
        currentRestTargetSeconds = nil

        cycleStartedAt = nowProvider()
        currentFocusTargetSeconds = settingsStore.focusSeconds
        mode = .focusing
        secondsUntilBreak = currentFocusTargetSeconds
    }

    private func handleScreenLocked() {
        resetCycle()
    }
}
