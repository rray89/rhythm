import Foundation

public enum TimerLifecyclePhase: String, Codable, Sendable {
    case focusing
    case resting
    case screenLocked
    case systemSleep
}

public struct TimerLifecycleSnapshot: Codable, Equatable, Sendable {
    public let phase: TimerLifecyclePhase
    public let startedAt: Date
    public let scheduledSeconds: Int
    public let breakKind: BreakKind?

    public init(
        phase: TimerLifecyclePhase,
        startedAt: Date,
        scheduledSeconds: Int,
        breakKind: BreakKind?
    ) {
        self.phase = phase
        self.startedAt = startedAt
        self.scheduledSeconds = scheduledSeconds
        self.breakKind = breakKind
    }
}

public struct AppLifecycleState: Codable, Equatable, Sendable {
    public let cleanExitAt: Date?
    public let lastHeartbeatAt: Date?
    public let lastSnapshot: TimerLifecycleSnapshot?

    public init(
        cleanExitAt: Date?,
        lastHeartbeatAt: Date?,
        lastSnapshot: TimerLifecycleSnapshot?
    ) {
        self.cleanExitAt = cleanExitAt
        self.lastHeartbeatAt = lastHeartbeatAt
        self.lastSnapshot = lastSnapshot
    }
}

public final class AppLifecycleStore {
    public static let stateFileName = "app-lifecycle.json"
    public static let heartbeatIntervalSeconds = 15 * 60
    public static let maximumDowntimeSeconds = 12 * 60 * 60

    private let stateDirectoryURL: URL
    private let stateFileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        let rootDirectoryURL: URL
        if let baseDirectoryURL {
            rootDirectoryURL = baseDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            rootDirectoryURL = appSupport.appendingPathComponent("Rhythm", isDirectory: true)
        }

        self.stateDirectoryURL = rootDirectoryURL.appendingPathComponent("state", isDirectory: true)
        self.stateFileURL = stateDirectoryURL.appendingPathComponent(Self.stateFileName, isDirectory: false)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func recordHeartbeat(at recordedAt: Date, snapshot: TimerLifecycleSnapshot) {
        save(AppLifecycleState(
            cleanExitAt: nil,
            lastHeartbeatAt: recordedAt,
            lastSnapshot: snapshot
        ))
    }

    public func recordCleanExit(at recordedAt: Date) {
        save(AppLifecycleState(
            cleanExitAt: recordedAt,
            lastHeartbeatAt: recordedAt,
            lastSnapshot: nil
        ))
    }

    @MainActor
    public func recoverPreviousRun(at launchedAt: Date, sessionStore: SessionRecording) {
        guard let state = loadState() else {
            return
        }

        if let cleanExitAt = state.cleanExitAt {
            addAppDowntime(from: cleanExitAt, to: launchedAt, sessionStore: sessionStore)
            clear()
            return
        }

        if let lastHeartbeatAt = state.lastHeartbeatAt {
            let estimatedExitAt = min(lastHeartbeatAt, launchedAt)
            if let snapshot = state.lastSnapshot {
                addRecoveredActiveSegment(from: snapshot, endedAt: estimatedExitAt, sessionStore: sessionStore)
            }
            addAppDowntime(from: estimatedExitAt, to: launchedAt, sessionStore: sessionStore)
        }

        clear()
    }

    public func loadState() -> AppLifecycleState? {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            return try decoder.decode(AppLifecycleState.self, from: data)
        } catch {
            return nil
        }
    }

    public func clear() {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return
        }

        try? fileManager.removeItem(at: stateFileURL)
        removeStateDirectoryIfEmpty()
    }

    @MainActor
    private func addRecoveredActiveSegment(
        from snapshot: TimerLifecycleSnapshot,
        endedAt: Date,
        sessionStore: SessionRecording
    ) {
        let actualSeconds = max(0, Int(endedAt.timeIntervalSince(snapshot.startedAt)))
        guard actualSeconds > 0 else {
            return
        }

        switch snapshot.phase {
        case .focusing:
            sessionStore.add(focusSession: FocusSession(
                scheduledFocusSeconds: snapshot.scheduledSeconds,
                actualFocusSeconds: actualSeconds,
                startedAt: snapshot.startedAt,
                endedAt: endedAt,
                endReason: .appExit
            ))
        case .resting:
            sessionStore.add(restSession: RestSession(
                breakKind: snapshot.breakKind ?? .standard,
                scheduledRestSeconds: snapshot.scheduledSeconds,
                actualRestSeconds: actualSeconds,
                startedAt: snapshot.startedAt,
                endedAt: endedAt,
                skipped: false,
                skipReason: nil,
                source: .timer
            ))
        case .screenLocked:
            sessionStore.add(restSession: RestSession(
                breakKind: .standard,
                scheduledRestSeconds: actualSeconds,
                actualRestSeconds: actualSeconds,
                startedAt: snapshot.startedAt,
                endedAt: endedAt,
                skipped: false,
                skipReason: nil,
                source: .screenLock
            ))
        case .systemSleep:
            sessionStore.add(restSession: RestSession(
                breakKind: .standard,
                scheduledRestSeconds: actualSeconds,
                actualRestSeconds: actualSeconds,
                startedAt: snapshot.startedAt,
                endedAt: endedAt,
                skipped: false,
                skipReason: nil,
                source: .systemSleep
            ))
        }
    }

    @MainActor
    private func addAppDowntime(from startedAt: Date, to endedAt: Date, sessionStore: SessionRecording) {
        let cappedEnd = min(endedAt, startedAt.addingTimeInterval(TimeInterval(Self.maximumDowntimeSeconds)))
        let actualSeconds = max(0, Int(cappedEnd.timeIntervalSince(startedAt)))
        guard actualSeconds > 0 else {
            return
        }

        sessionStore.add(restSession: RestSession(
            breakKind: .standard,
            scheduledRestSeconds: actualSeconds,
            actualRestSeconds: actualSeconds,
            startedAt: startedAt,
            endedAt: cappedEnd,
            skipped: false,
            skipReason: nil,
            source: .appDowntime
        ))
    }

    private func save(_ state: AppLifecycleState) {
        do {
            if !fileManager.fileExists(atPath: stateDirectoryURL.path) {
                try fileManager.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true)
            }

            let data = try encoder.encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            // Lifecycle recovery is best-effort; never crash the menu bar app on state writes.
        }
    }

    private func removeStateDirectoryIfEmpty() {
        let contents = (try? fileManager.contentsOfDirectory(
            at: stateDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        if contents.isEmpty {
            try? fileManager.removeItem(at: stateDirectoryURL)
        }
    }
}
