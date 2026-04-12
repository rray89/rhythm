import Foundation

public enum RestSessionSource: String, Codable, Sendable {
    case timer
    case screenLock
    case systemSleep
    case appDowntime
}

public enum FocusEndReason: String, Codable, Sendable {
    case scheduledBreak
    case manualBreak
    case reset
    case screenLock
    case systemSleep
    case appExit
}

public struct FocusSession: Codable, Identifiable, Sendable {
    public let id: UUID
    public let scheduledFocusSeconds: Int
    public let actualFocusSeconds: Int
    public let startedAt: Date
    public let endedAt: Date
    public let endReason: FocusEndReason
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        scheduledFocusSeconds: Int,
        actualFocusSeconds: Int,
        startedAt: Date,
        endedAt: Date,
        endReason: FocusEndReason,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.scheduledFocusSeconds = scheduledFocusSeconds
        self.actualFocusSeconds = actualFocusSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.createdAt = createdAt
    }
}

public struct RestSession: Codable, Identifiable, Sendable {
    public let id: UUID
    public let breakKind: BreakKind
    public let scheduledRestSeconds: Int
    public let actualRestSeconds: Int
    public let startedAt: Date
    public let endedAt: Date
    public let skipped: Bool
    public let skipReason: String?
    public let source: RestSessionSource
    public let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case breakKind
        case scheduledRestSeconds
        case actualRestSeconds
        case startedAt
        case endedAt
        case skipped
        case skipReason
        case source
        case createdAt
    }

    public init(
        id: UUID = UUID(),
        breakKind: BreakKind = .standard,
        scheduledRestSeconds: Int,
        actualRestSeconds: Int,
        startedAt: Date,
        endedAt: Date,
        skipped: Bool,
        skipReason: String? = nil,
        source: RestSessionSource = .timer,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.breakKind = breakKind
        self.scheduledRestSeconds = scheduledRestSeconds
        self.actualRestSeconds = actualRestSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.skipped = skipped
        self.skipReason = skipReason
        self.source = source
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        breakKind = try container.decodeIfPresent(BreakKind.self, forKey: .breakKind) ?? .standard
        scheduledRestSeconds = try container.decode(Int.self, forKey: .scheduledRestSeconds)
        actualRestSeconds = try container.decode(Int.self, forKey: .actualRestSeconds)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        skipped = try container.decode(Bool.self, forKey: .skipped)
        skipReason = try container.decodeIfPresent(String.self, forKey: .skipReason)
        source = try container.decodeIfPresent(RestSessionSource.self, forKey: .source) ?? .timer
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(breakKind, forKey: .breakKind)
        try container.encode(scheduledRestSeconds, forKey: .scheduledRestSeconds)
        try container.encode(actualRestSeconds, forKey: .actualRestSeconds)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(skipped, forKey: .skipped)
        try container.encodeIfPresent(skipReason, forKey: .skipReason)
        try container.encode(source, forKey: .source)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

public struct SessionTimelineEntry: Identifiable, Sendable {
    public enum Kind: Sendable {
        case focus(FocusSession)
        case rest(RestSession)
    }

    public let kind: Kind
    public let startedAt: Date

    public var id: String {
        switch kind {
        case .focus(let session):
            return "focus-\(session.id.uuidString)"
        case .rest(let session):
            return "rest-\(session.id.uuidString)"
        }
    }

    public init(kind: Kind, startedAt: Date) {
        self.kind = kind
        self.startedAt = startedAt
    }
}

@MainActor
public protocol SessionRecording: AnyObject {
    func add(restSession: RestSession)
    func add(focusSession: FocusSession)
}

@MainActor
public final class SessionStore: ObservableObject {
    public static let legacyRestFileName = "sessions.json"
    public static let focusSessionsFileName = "focus-sessions.json"
    public static let restSessionsFileName = "rest-sessions.json"

    @Published public private(set) var sessions: [RestSession] = []
    @Published public private(set) var restSessions: [RestSession] = []
    @Published public private(set) var focusSessions: [FocusSession] = []
    @Published public private(set) var historyEntries: [SessionTimelineEntry] = []

    private let rootDirectoryURL: URL
    private let weeksDirectoryURL: URL
    private let legacyRestFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let calendar: Calendar

    public init(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        calendar: Calendar = .current
    ) {
        self.fileManager = fileManager
        self.calendar = Self.reportingCalendar(from: calendar)

        if let baseDirectoryURL {
            self.rootDirectoryURL = baseDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.rootDirectoryURL = appSupport.appendingPathComponent("Rhythm", isDirectory: true)
        }

        let historyDirectoryURL = rootDirectoryURL.appendingPathComponent("history", isDirectory: true)
        self.weeksDirectoryURL = historyDirectoryURL.appendingPathComponent("weeks", isDirectory: true)
        self.legacyRestFileURL = rootDirectoryURL.appendingPathComponent(Self.legacyRestFileName, isDirectory: false)

        if !fileManager.fileExists(atPath: weeksDirectoryURL.path) {
            try? fileManager.createDirectory(at: weeksDirectoryURL, withIntermediateDirectories: true)
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    public func add(restSession: RestSession) {
        restSessions.insert(restSession, at: 0)
        rebuildDerivedViews()
        saveRestSessions()
    }

    public func add(focusSession: FocusSession) {
        focusSessions.insert(focusSession, at: 0)
        rebuildDerivedViews()
        saveFocusSessions()
    }

    public func summary(
        activePhase: ActiveSessionSnapshot?,
        dayBoundaryHour: Int,
        now: Date = Date()
    ) -> DailyTotalsSnapshot {
        DailyTotalsCalculator.snapshot(
            focusSessions: focusSessions,
            restSessions: restSessions,
            activePhase: activePhase,
            dayBoundaryHour: dayBoundaryHour,
            now: now,
            calendar: calendar
        )
    }

    public func insights(
        activePhase: ActiveSessionSnapshot?,
        dayBoundaryHour: Int,
        now: Date = Date()
    ) -> HistoryInsightsSnapshot {
        HistoryInsightsCalculator.snapshot(
            focusSessions: focusSessions,
            restSessions: restSessions,
            activePhase: activePhase,
            dayBoundaryHour: dayBoundaryHour,
            now: now,
            calendar: calendar
        )
    }

    public func exportHistory(
        scope: HistoryDisplayRange,
        format: HistoryExportFormat,
        dayBoundaryHour: Int,
        now: Date = Date()
    ) throws -> HistoryExportPayload {
        try HistoryInsightsCalculator.export(
            scope: scope,
            format: format,
            focusSessions: focusSessions,
            restSessions: restSessions,
            dayBoundaryHour: dayBoundaryHour,
            now: now,
            calendar: calendar
        )
    }

    private func load() {
        restSessions = loadRestSessionsFromWeeks().sorted { $0.startedAt > $1.startedAt }
        focusSessions = loadFocusSessionsFromWeeks().sorted { $0.startedAt > $1.startedAt }

        migrateLegacyRestSessionsIfNeeded()
        rebuildDerivedViews()
    }

    private func rebuildDerivedViews() {
        restSessions.sort { $0.startedAt > $1.startedAt }
        focusSessions.sort { $0.startedAt > $1.startedAt }
        sessions = restSessions.filter { $0.source == .timer }

        historyEntries = (
            focusSessions.map { SessionTimelineEntry(kind: .focus($0), startedAt: $0.startedAt) } +
            restSessions.map { SessionTimelineEntry(kind: .rest($0), startedAt: $0.startedAt) }
        )
        .sorted { $0.startedAt > $1.startedAt }
    }

    private func migrateLegacyRestSessionsIfNeeded() {
        guard fileManager.fileExists(atPath: legacyRestFileURL.path) else {
            return
        }

        guard let legacySessions: [RestSession] = loadJSON([RestSession].self, from: legacyRestFileURL) else {
            return
        }

        var mergedByID = Dictionary(uniqueKeysWithValues: restSessions.map { ($0.id, $0) })
        for session in legacySessions {
            mergedByID[session.id] = session
        }

        restSessions = mergedByID.values.sorted { $0.startedAt > $1.startedAt }
        rebuildDerivedViews()
        saveRestSessions()
        try? fileManager.removeItem(at: legacyRestFileURL)
    }

    private func loadRestSessionsFromWeeks() -> [RestSession] {
        weekDirectories().compactMap { directory in
            loadJSON([RestSession].self, from: directory.appendingPathComponent(Self.restSessionsFileName, isDirectory: false))
        }
        .flatMap { $0 }
    }

    private func loadFocusSessionsFromWeeks() -> [FocusSession] {
        weekDirectories().compactMap { directory in
            loadJSON([FocusSession].self, from: directory.appendingPathComponent(Self.focusSessionsFileName, isDirectory: false))
        }
        .flatMap { $0 }
    }

    private func saveRestSessions() {
        removeExistingWeeklyFiles(named: Self.restSessionsFileName)

        let groupedSessions = Dictionary(grouping: restSessions) { weekFolderName(for: $0.startedAt) }
        for (folderName, sessions) in groupedSessions {
            let directoryURL = weeksDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let sortedSessions = sessions.sorted { $0.startedAt < $1.startedAt }
            saveJSON(sortedSessions, to: directoryURL.appendingPathComponent(Self.restSessionsFileName, isDirectory: false))
        }

        removeEmptyWeekDirectories()
    }

    private func saveFocusSessions() {
        removeExistingWeeklyFiles(named: Self.focusSessionsFileName)

        let groupedSessions = Dictionary(grouping: focusSessions) { weekFolderName(for: $0.startedAt) }
        for (folderName, sessions) in groupedSessions {
            let directoryURL = weeksDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let sortedSessions = sessions.sorted { $0.startedAt < $1.startedAt }
            saveJSON(sortedSessions, to: directoryURL.appendingPathComponent(Self.focusSessionsFileName, isDirectory: false))
        }

        removeEmptyWeekDirectories()
    }

    private func weekDirectories() -> [URL] {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: weeksDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return directories.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private func removeExistingWeeklyFiles(named fileName: String) {
        for directory in weekDirectories() {
            let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func removeEmptyWeekDirectories() {
        for directory in weekDirectories() {
            let contents = (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            if contents.isEmpty {
                try? fileManager.removeItem(at: directory)
            }
        }
    }

    private func weekFolderName(for date: Date) -> String {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startOfWeek)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private func saveJSON<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            // Intentionally swallow write errors to avoid crashing the menu bar app.
        }
    }

    private static func reportingCalendar(from base: Calendar) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

extension SessionStore: SessionRecording {}

@MainActor
public protocol RhythmSettings: AnyObject {
    var focusSeconds: Int { get }
    var restSeconds: Int { get }
    var skipRestEnabled: Bool { get }
    var onDidChange: (() -> Void)? { get set }
}

@MainActor
public final class SettingsStore: ObservableObject {
    public static let focusMinutesKey = "focusMinutes"
    public static let restSecondsKey = "restSeconds"
    public static let legacyRestMinutesKey = "restMinutes"
    public static let skipRestEnabledKey = "skipRestEnabled"
    public static let dayBoundaryHourKey = "dayBoundaryHour"
    public static let appLanguageOverrideKey = "appLanguageOverride"

    public static let minFocusMinutes = 10
    public static let maxFocusMinutes = 120
    public static let focusMinutesStep = 5

    public static let minRestSeconds = 30
    public static let maxRestSeconds = 1_200
    public static let restPresetSeconds = [30, 60, 90, 120, 180, 240, 300, 600, 900, 1_200]

    public static let minDayBoundaryHour = 0
    public static let maxDayBoundaryHour = 23

    @Published public var focusMinutes: Int {
        didSet {
            let normalized = Self.normalizeFocusMinutes(focusMinutes)
            if focusMinutes != normalized {
                focusMinutes = normalized
                return
            }
            if oldValue == focusMinutes {
                return
            }
            userDefaults.set(focusMinutes, forKey: Self.focusMinutesKey)
            onDidChange?()
        }
    }

    @Published public var restSeconds: Int {
        didSet {
            let normalized = Self.normalizeRestSeconds(restSeconds)
            if restSeconds != normalized {
                restSeconds = normalized
                return
            }
            if oldValue == restSeconds {
                return
            }
            userDefaults.set(restSeconds, forKey: Self.restSecondsKey)
            onDidChange?()
        }
    }

    @Published public var skipRestEnabled: Bool {
        didSet {
            if oldValue == skipRestEnabled {
                return
            }
            userDefaults.set(skipRestEnabled, forKey: Self.skipRestEnabledKey)
            onDidChange?()
        }
    }

    @Published public var dayBoundaryHour: Int {
        didSet {
            let normalized = Self.normalizeDayBoundaryHour(dayBoundaryHour)
            if dayBoundaryHour != normalized {
                dayBoundaryHour = normalized
                return
            }
            if oldValue == dayBoundaryHour {
                return
            }
            userDefaults.set(dayBoundaryHour, forKey: Self.dayBoundaryHourKey)
            onDidChange?()
        }
    }

    @Published public var appLanguageOverride: AppLanguage? {
        didSet {
            if oldValue == appLanguageOverride {
                return
            }

            if let appLanguageOverride {
                userDefaults.set(appLanguageOverride.rawValue, forKey: Self.appLanguageOverrideKey)
            } else {
                userDefaults.removeObject(forKey: Self.appLanguageOverrideKey)
            }
        }
    }

    public var onDidChange: (() -> Void)?

    public var focusSeconds: Int { focusMinutes * 60 }
    public var effectiveAppLanguage: AppLanguage {
        appLanguageOverride ?? AppLanguage.resolveSystemLanguage(from: preferredLanguagesProvider())
    }

    private let userDefaults: UserDefaults
    private let preferredLanguagesProvider: () -> [String]

    public init(
        userDefaults: UserDefaults = .standard,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.userDefaults = userDefaults
        self.preferredLanguagesProvider = preferredLanguagesProvider
        let storedFocus = userDefaults.object(forKey: Self.focusMinutesKey) as? Int
        self.focusMinutes = Self.normalizeFocusMinutes(storedFocus ?? 30)

        if let storedRestSeconds = userDefaults.object(forKey: Self.restSecondsKey) as? Int {
            self.restSeconds = Self.normalizeRestSeconds(storedRestSeconds)
        } else if let storedLegacyRestMinutes = userDefaults.object(forKey: Self.legacyRestMinutesKey) as? Int {
            self.restSeconds = Self.normalizeRestSeconds(storedLegacyRestMinutes * 60)
        } else {
            self.restSeconds = Self.normalizeRestSeconds(60)
        }

        if let storedSkipRestEnabled = userDefaults.object(forKey: Self.skipRestEnabledKey) as? Bool {
            self.skipRestEnabled = storedSkipRestEnabled
        } else {
            self.skipRestEnabled = false
        }

        if let storedDayBoundaryHour = userDefaults.object(forKey: Self.dayBoundaryHourKey) as? Int {
            self.dayBoundaryHour = Self.normalizeDayBoundaryHour(storedDayBoundaryHour)
        } else {
            self.dayBoundaryHour = Self.normalizeDayBoundaryHour(0)
        }

        if let storedAppLanguage = userDefaults.string(forKey: Self.appLanguageOverrideKey) {
            self.appLanguageOverride = AppLanguage(rawValue: storedAppLanguage)
        } else {
            self.appLanguageOverride = nil
        }
    }

    private static func normalizeFocusMinutes(_ value: Int) -> Int {
        normalize(value, min: minFocusMinutes, max: maxFocusMinutes, step: focusMinutesStep)
    }

    private static func normalizeRestSeconds(_ value: Int) -> Int {
        let clamped = Swift.max(minRestSeconds, Swift.min(maxRestSeconds, value))
        return restPresetSeconds.min { lhs, rhs in
            abs(lhs - clamped) < abs(rhs - clamped)
        } ?? minRestSeconds
    }

    private static func normalizeDayBoundaryHour(_ value: Int) -> Int {
        Swift.max(minDayBoundaryHour, Swift.min(maxDayBoundaryHour, value))
    }

    private static func normalize(_ value: Int, min: Int, max: Int, step: Int) -> Int {
        guard step > 0 else { return Swift.max(min, Swift.min(max, value)) }
        let clamped = Swift.max(min, Swift.min(max, value))
        let offset = clamped - min
        let roundedSteps = Int((Double(offset) / Double(step)).rounded())
        let snapped = min + roundedSteps * step
        return Swift.max(min, Swift.min(max, snapped))
    }
}

extension SettingsStore: RhythmSettings {}
