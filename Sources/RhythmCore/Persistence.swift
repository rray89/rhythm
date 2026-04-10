import Foundation

public struct RestSession: Codable, Identifiable {
    public let id: UUID
    public let breakKind: BreakKind
    public let scheduledRestSeconds: Int
    public let actualRestSeconds: Int
    public let startedAt: Date
    public let endedAt: Date
    public let skipped: Bool
    public let skipReason: String?
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
        try container.encode(createdAt, forKey: .createdAt)
    }
}

@MainActor
public final class SessionStore: ObservableObject {
    @Published public private(set) var sessions: [RestSession] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("Rhythm", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("sessions.json", isDirectory: false)

        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    public func add(_ session: RestSession) {
        sessions.insert(session, at: 0)
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            sessions = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try decoder.decode([RestSession].self, from: data)
        } catch {
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Intentionally swallow write errors in V1 to avoid crashing the menu bar app.
        }
    }
}

extension SessionStore: RestSessionStoring {}

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
    public static let appLanguageOverrideKey = "appLanguageOverride"

    public static let minFocusMinutes = 10
    public static let maxFocusMinutes = 120
    public static let focusMinutesStep = 5

    public static let minRestSeconds = 30
    public static let maxRestSeconds = 1_200
    public static let restPresetSeconds = [30, 60, 90, 120, 180, 240, 300, 600, 900, 1_200]

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
