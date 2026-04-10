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
    var onExtendRequested: ((Int) -> Void)? { get set }
    func present(restSeconds: Int, breakKind: BreakKind)
    func updateRemaining(restSeconds: Int)
    func dismiss()
    func skipByEscape()
}

@MainActor
public protocol BreakCompletionNotifying: AnyObject {
    func notifyBreakCompleted(kind: BreakKind)
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
    @Published public private(set) var secondsRemainingInPhase: Int
    @Published public private(set) var activeBreakKind: BreakKind?

    public var statusItemCountdownSeconds: Int {
        switch mode {
        case .focusing:
            return secondsUntilBreak
        case .resting:
            return secondsRemainingInPhase
        }
    }

    private let settingsStore: RhythmSettings
    private let sessionStore: RestSessionStoring
    private let overlayManager: RestOverlaying
    private let lockMonitor: ScreenLockMonitoring
    private let breakNotifier: BreakCompletionNotifying?
    private let nowProvider: () -> Date
    private let useSystemTimer: Bool

    private var cycleStartedAt = Date()
    private var restStartedAt: Date?
    private var currentFocusTargetSeconds: Int
    private var currentRestTargetSeconds: Int?
    private var currentBreakKind: BreakKind?
    private var timer: Timer?

    public init(
        settingsStore: RhythmSettings,
        sessionStore: RestSessionStoring,
        overlayManager: RestOverlaying,
        lockMonitor: ScreenLockMonitoring,
        breakNotifier: BreakCompletionNotifying? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        autoStart: Bool = true,
        useSystemTimer: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.overlayManager = overlayManager
        self.lockMonitor = lockMonitor
        self.breakNotifier = breakNotifier
        self.nowProvider = nowProvider
        self.useSystemTimer = useSystemTimer
        self.currentFocusTargetSeconds = settingsStore.focusSeconds
        self.secondsUntilBreak = settingsStore.focusSeconds
        self.secondsRemainingInPhase = settingsStore.focusSeconds
        self.activeBreakKind = nil

        overlayManager.onSkipped = { [weak self] in
            self?.finishRest(skipped: true, skipReason: "esc")
        }

        overlayManager.onExtendRequested = { [weak self] seconds in
            self?.extendRest(by: seconds)
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
        currentBreakKind = nil
        activeBreakKind = nil
        secondsUntilBreak = currentFocusTargetSeconds
        secondsRemainingInPhase = currentFocusTargetSeconds
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
        currentBreakKind = nil
        activeBreakKind = nil
        cycleStartedAt = nowProvider()
        mode = .focusing
        secondsUntilBreak = currentFocusTargetSeconds
        secondsRemainingInPhase = currentFocusTargetSeconds
    }

    public func startBreakNow() {
        guard mode == .focusing else { return }
        beginResting(kind: .standard, durationSeconds: settingsStore.restSeconds)
    }

    public func startBreak(preset: BreakPreset) {
        guard mode == .focusing else { return }
        beginResting(kind: preset.kind, durationSeconds: preset.durationSeconds)
    }

    public func skipBreak() {
        guard mode == .resting else { return }
        if (currentBreakKind ?? .standard).usesBlockingOverlay {
            overlayManager.skipByEscape()
        } else {
            finishRest(skipped: true, skipReason: "manual")
        }
    }

    public func extendFocus(by seconds: Int) {
        guard mode == .focusing, seconds > 0 else { return }
        currentFocusTargetSeconds += seconds
        processTick(now: nowProvider())
    }

    public func canShortenFocus(by seconds: Int) -> Bool {
        guard mode == .focusing, seconds > 0 else { return false }
        return focusRemainingSeconds(at: nowProvider()) >= seconds
    }

    public func shortenFocus(by seconds: Int) {
        let now = nowProvider()
        guard mode == .focusing, seconds > 0 else { return }
        guard focusRemainingSeconds(at: now) >= seconds else { return }

        currentFocusTargetSeconds -= seconds
        processTick(now: now)
    }

    public func extendRest(by seconds: Int) {
        guard mode == .resting, seconds > 0 else { return }
        currentRestTargetSeconds = (currentRestTargetSeconds ?? settingsStore.restSeconds) + seconds
        let remaining = restRemainingSeconds(at: nowProvider())
        secondsRemainingInPhase = remaining
        overlayManager.updateRemaining(restSeconds: remaining)
    }

    public func processTick(now: Date) {
        switch mode {
        case .focusing:
            let remaining = focusRemainingSeconds(at: now)
            secondsUntilBreak = remaining
            secondsRemainingInPhase = remaining

            if remaining == 0 {
                beginScheduledRest()
            }
        case .resting:
            let remaining = restRemainingSeconds(at: now)
            secondsRemainingInPhase = remaining
            overlayManager.updateRemaining(restSeconds: remaining)

            if remaining == 0 {
                finishRest(skipped: false, skipReason: nil)
            }
        }
    }

    private func beginScheduledRest() {
        if settingsStore.skipRestEnabled {
            let now = nowProvider()
            let session = RestSession(
                breakKind: .standard,
                scheduledRestSeconds: settingsStore.restSeconds,
                actualRestSeconds: 0,
                startedAt: now,
                endedAt: now,
                skipped: true,
                skipReason: "no_rest"
            )
            sessionStore.add(session)
            currentRestTargetSeconds = nil
            currentBreakKind = nil
            activeBreakKind = nil
            cycleStartedAt = now
            currentFocusTargetSeconds = settingsStore.focusSeconds
            mode = .focusing
            secondsUntilBreak = currentFocusTargetSeconds
            secondsRemainingInPhase = currentFocusTargetSeconds
            return
        }

        beginResting(kind: .standard, durationSeconds: settingsStore.restSeconds)
    }

    private func beginResting(kind: BreakKind, durationSeconds: Int) {
        mode = .resting
        restStartedAt = nowProvider()
        currentRestTargetSeconds = durationSeconds
        currentBreakKind = kind
        activeBreakKind = kind
        secondsRemainingInPhase = durationSeconds
        overlayManager.present(restSeconds: durationSeconds, breakKind: kind)
    }

    private func finishRest(skipped: Bool, skipReason: String?) {
        guard mode == .resting, let restStartedAt else { return }

        let endedAt = nowProvider()
        let actualSeconds = max(0, Int(endedAt.timeIntervalSince(restStartedAt)))
        let breakKind = currentBreakKind ?? .standard
        let shouldNotifyCompletion = !skipped && !breakKind.usesBlockingOverlay
        overlayManager.dismiss()
        let session = RestSession(
            breakKind: breakKind,
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
        currentBreakKind = nil
        activeBreakKind = nil

        cycleStartedAt = nowProvider()
        currentFocusTargetSeconds = settingsStore.focusSeconds
        mode = .focusing
        secondsUntilBreak = currentFocusTargetSeconds
        secondsRemainingInPhase = currentFocusTargetSeconds

        if shouldNotifyCompletion {
            breakNotifier?.notifyBreakCompleted(kind: breakKind)
        }
    }

    private func handleScreenLocked() {
        resetCycle()
    }

    private func focusRemainingSeconds(at now: Date) -> Int {
        let elapsed = Int(now.timeIntervalSince(cycleStartedAt))
        return max(0, currentFocusTargetSeconds - elapsed)
    }

    private func restRemainingSeconds(at now: Date) -> Int {
        guard let restStartedAt, let currentRestTargetSeconds else { return 0 }
        let elapsed = Int(now.timeIntervalSince(restStartedAt))
        return max(0, currentRestTargetSeconds - elapsed)
    }
}
