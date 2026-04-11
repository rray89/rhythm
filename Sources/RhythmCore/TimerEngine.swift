import Foundation

public enum RhythmMode: Equatable {
    case focusing
    case resting
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
    var onScreenUnlocked: (() -> Void)? { get set }
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

    public var activeSessionSnapshot: ActiveSessionSnapshot? {
        guard screenLockStartedAt == nil else {
            return nil
        }

        switch mode {
        case .focusing:
            return ActiveSessionSnapshot(
                kind: .focus,
                startedAt: cycleStartedAt,
                scheduledSeconds: currentFocusTargetSeconds,
                breakKind: nil
            )
        case .resting:
            guard let restStartedAt else {
                return nil
            }

            return ActiveSessionSnapshot(
                kind: .rest,
                startedAt: restStartedAt,
                scheduledSeconds: currentRestTargetSeconds ?? settingsStore.restSeconds,
                breakKind: currentBreakKind ?? .standard
            )
        }
    }

    private let settingsStore: RhythmSettings
    private let sessionStore: SessionRecording
    private let overlayManager: RestOverlaying
    private let lockMonitor: ScreenLockMonitoring
    private let breakNotifier: BreakCompletionNotifying?
    private let nowProvider: () -> Date
    private let useSystemTimer: Bool

    private var cycleStartedAt = Date()
    private var restStartedAt: Date?
    private var screenLockStartedAt: Date?
    private var currentFocusTargetSeconds: Int
    private var currentRestTargetSeconds: Int?
    private var currentBreakKind: BreakKind?
    private var timer: Timer?

    public init(
        settingsStore: RhythmSettings,
        sessionStore: SessionRecording,
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

        lockMonitor.onScreenUnlocked = { [weak self] in
            self?.handleScreenUnlocked()
        }

        if autoStart {
            start()
        }
    }

    public func start() {
        timer?.invalidate()
        startFocusCycle(at: nowProvider(), dismissOverlay: false)
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
        let now = nowProvider()

        if screenLockStartedAt != nil {
            startFocusCycle(at: now)
            return
        }

        if mode == .focusing {
            recordCurrentFocusSession(endedAt: now, endReason: .reset)
        }

        startFocusCycle(at: now)
    }

    public func startBreakNow() {
        guard mode == .focusing, screenLockStartedAt == nil else { return }
        let now = nowProvider()
        recordCurrentFocusSession(endedAt: now, endReason: .manualBreak)
        beginResting(kind: .standard, durationSeconds: settingsStore.restSeconds, startedAt: now)
    }

    public func startBreak(preset: BreakPreset) {
        guard mode == .focusing, screenLockStartedAt == nil else { return }
        let now = nowProvider()
        recordCurrentFocusSession(endedAt: now, endReason: .manualBreak)
        beginResting(kind: preset.kind, durationSeconds: preset.durationSeconds, startedAt: now)
    }

    public func skipBreak() {
        guard mode == .resting, screenLockStartedAt == nil else { return }
        if (currentBreakKind ?? .standard).usesBlockingOverlay {
            overlayManager.skipByEscape()
        } else {
            finishRest(skipped: true, skipReason: "manual")
        }
    }

    public func extendFocus(by seconds: Int) {
        guard mode == .focusing, screenLockStartedAt == nil, seconds > 0 else { return }
        currentFocusTargetSeconds += seconds
        processTick(now: nowProvider())
    }

    public func canShortenFocus(by seconds: Int) -> Bool {
        guard mode == .focusing, screenLockStartedAt == nil, seconds > 0 else { return false }
        return focusRemainingSeconds(at: nowProvider()) >= seconds
    }

    public func shortenFocus(by seconds: Int) {
        let now = nowProvider()
        guard mode == .focusing, screenLockStartedAt == nil, seconds > 0 else { return }
        guard focusRemainingSeconds(at: now) >= seconds else { return }

        currentFocusTargetSeconds -= seconds
        processTick(now: now)
    }

    public func extendRest(by seconds: Int) {
        guard mode == .resting, screenLockStartedAt == nil, seconds > 0 else { return }
        currentRestTargetSeconds = (currentRestTargetSeconds ?? settingsStore.restSeconds) + seconds
        let remaining = restRemainingSeconds(at: nowProvider())
        secondsRemainingInPhase = remaining
        overlayManager.updateRemaining(restSeconds: remaining)
    }

    public func processTick(now: Date) {
        guard screenLockStartedAt == nil else {
            return
        }

        switch mode {
        case .focusing:
            let remaining = focusRemainingSeconds(at: now)
            secondsUntilBreak = remaining
            secondsRemainingInPhase = remaining

            if remaining == 0 {
                beginScheduledRest(at: now)
            }
        case .resting:
            let remaining = restRemainingSeconds(at: now)
            secondsRemainingInPhase = remaining
            overlayManager.updateRemaining(restSeconds: remaining)

            if remaining == 0 {
                finishRest(skipped: false, skipReason: nil, endedAt: now)
            }
        }
    }

    private func beginScheduledRest(at now: Date) {
        recordCurrentFocusSession(endedAt: now, endReason: .scheduledBreak)

        if settingsStore.skipRestEnabled {
            let session = RestSession(
                breakKind: .standard,
                scheduledRestSeconds: settingsStore.restSeconds,
                actualRestSeconds: 0,
                startedAt: now,
                endedAt: now,
                skipped: true,
                skipReason: "no_rest",
                source: .timer
            )
            sessionStore.add(restSession: session)
            startFocusCycle(at: now, dismissOverlay: false)
            return
        }

        beginResting(kind: .standard, durationSeconds: settingsStore.restSeconds, startedAt: now)
    }

    private func beginResting(kind: BreakKind, durationSeconds: Int, startedAt: Date) {
        mode = .resting
        restStartedAt = startedAt
        currentRestTargetSeconds = durationSeconds
        currentBreakKind = kind
        activeBreakKind = kind
        secondsRemainingInPhase = durationSeconds
        overlayManager.present(restSeconds: durationSeconds, breakKind: kind)
    }

    private func finishRest(
        skipped: Bool,
        skipReason: String?,
        endedAt: Date? = nil
    ) {
        let now = endedAt ?? nowProvider()
        guard let result = completeCurrentRestSession(
            endedAt: now,
            skipped: skipped,
            skipReason: skipReason,
            source: .timer
        ) else {
            return
        }

        startFocusCycle(at: now, dismissOverlay: false)

        if result.shouldNotify {
            breakNotifier?.notifyBreakCompleted(kind: result.breakKind)
        }
    }

    private func handleScreenLocked() {
        let now = nowProvider()
        guard screenLockStartedAt == nil else { return }

        switch mode {
        case .focusing:
            recordCurrentFocusSession(endedAt: now, endReason: .screenLock)
            overlayManager.dismiss()
        case .resting:
            _ = completeCurrentRestSession(
                endedAt: now,
                skipped: false,
                skipReason: nil,
                source: .timer
            )
        }

        screenLockStartedAt = now
        restStartedAt = nil
        currentRestTargetSeconds = nil
        currentBreakKind = nil
        activeBreakKind = nil
        mode = .focusing
        currentFocusTargetSeconds = settingsStore.focusSeconds
        secondsUntilBreak = currentFocusTargetSeconds
        secondsRemainingInPhase = currentFocusTargetSeconds
    }

    private func handleScreenUnlocked() {
        guard let screenLockStartedAt else { return }
        let now = nowProvider()
        let actualSeconds = max(0, Int(now.timeIntervalSince(screenLockStartedAt)))

        let hiddenRest = RestSession(
            breakKind: .standard,
            scheduledRestSeconds: actualSeconds,
            actualRestSeconds: actualSeconds,
            startedAt: screenLockStartedAt,
            endedAt: now,
            skipped: false,
            skipReason: nil,
            source: .screenLock
        )
        sessionStore.add(restSession: hiddenRest)
        startFocusCycle(at: now)
    }

    private func startFocusCycle(at startedAt: Date, dismissOverlay: Bool = true) {
        if dismissOverlay {
            overlayManager.dismiss()
        }

        screenLockStartedAt = nil
        restStartedAt = nil
        currentRestTargetSeconds = nil
        currentBreakKind = nil
        activeBreakKind = nil

        cycleStartedAt = startedAt
        currentFocusTargetSeconds = settingsStore.focusSeconds
        mode = .focusing
        secondsUntilBreak = currentFocusTargetSeconds
        secondsRemainingInPhase = currentFocusTargetSeconds
    }

    private func recordCurrentFocusSession(endedAt: Date, endReason: FocusEndReason) {
        guard mode == .focusing else { return }

        let actualSeconds = max(0, Int(endedAt.timeIntervalSince(cycleStartedAt)))
        guard actualSeconds > 0 else { return }

        let session = FocusSession(
            scheduledFocusSeconds: currentFocusTargetSeconds,
            actualFocusSeconds: actualSeconds,
            startedAt: cycleStartedAt,
            endedAt: endedAt,
            endReason: endReason
        )
        sessionStore.add(focusSession: session)
    }

    private func completeCurrentRestSession(
        endedAt: Date,
        skipped: Bool,
        skipReason: String?,
        source: RestSessionSource
    ) -> (breakKind: BreakKind, shouldNotify: Bool)? {
        guard mode == .resting, let restStartedAt else { return nil }

        let actualSeconds = max(0, Int(endedAt.timeIntervalSince(restStartedAt)))
        let breakKind = currentBreakKind ?? .standard
        let shouldNotify = source == .timer && !skipped && !breakKind.usesBlockingOverlay

        overlayManager.dismiss()

        let session = RestSession(
            breakKind: breakKind,
            scheduledRestSeconds: currentRestTargetSeconds ?? settingsStore.restSeconds,
            actualRestSeconds: actualSeconds,
            startedAt: restStartedAt,
            endedAt: endedAt,
            skipped: skipped,
            skipReason: skipReason,
            source: source
        )
        sessionStore.add(restSession: session)

        self.restStartedAt = nil
        currentRestTargetSeconds = nil
        currentBreakKind = nil
        activeBreakKind = nil

        return (breakKind, shouldNotify)
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
