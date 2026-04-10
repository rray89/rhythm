import Foundation
import RhythmCore

@main
@MainActor
struct RhythmTDDRunner {
    static func main() {
        var failures = 0
        let includeUI = ProcessInfo.processInfo.environment["RHYTHM_TDD_UI"] != "0"

        failures += run("settings change callback fires once") {
            let isolated = makeIsolatedDefaults()
            defer { isolated.defaults.removePersistentDomain(forName: isolated.suiteName) }

            let store = SettingsStore(userDefaults: isolated.defaults)
            var callbackCount = 0
            store.onDidChange = {
                callbackCount += 1
            }
            store.focusMinutes = 35

            guard store.focusMinutes == 35 else { return false }
            return callbackCount == 1
        }

        failures += run("default settings are 30m focus and 1m rest") {
            let isolated = makeIsolatedDefaults()
            defer { isolated.defaults.removePersistentDomain(forName: isolated.suiteName) }

            let store = SettingsStore(userDefaults: isolated.defaults)
            guard store.focusMinutes == 30 else { return false }
            return store.restSeconds == 60
        }

        failures += run("settings normalization keeps configured range and rest presets") {
            let isolated = makeIsolatedDefaults()
            defer { isolated.defaults.removePersistentDomain(forName: isolated.suiteName) }

            let store = SettingsStore(userDefaults: isolated.defaults)
            store.focusMinutes = 0
            guard store.focusMinutes == 10 else { return false }

            store.restSeconds = 1
            guard store.restSeconds == 30 else { return false }

            store.restSeconds = 250
            guard store.restSeconds == 240 else { return false }

            store.focusMinutes = 119
            guard store.focusMinutes == 120 else { return false }

            store.restSeconds = 589
            return store.restSeconds == 600
        }

        failures += run("legacy rest minutes migrates to rest seconds") {
            let isolated = makeIsolatedDefaults()
            defer { isolated.defaults.removePersistentDomain(forName: isolated.suiteName) }

            isolated.defaults.set(3, forKey: SettingsStore.legacyRestMinutesKey)
            let store = SettingsStore(userDefaults: isolated.defaults)
            return store.restSeconds == 180
        }

        failures += run("system language resolves chinese only for zh locales") {
            guard AppLanguage.resolveSystemLanguage(from: ["zh-Hans"]) == .chinese else { return false }
            guard AppLanguage.resolveSystemLanguage(from: ["zh-Hant"]) == .chinese else { return false }
            guard AppLanguage.resolveSystemLanguage(from: ["zh-CN"]) == .chinese else { return false }
            guard AppLanguage.resolveSystemLanguage(from: ["en-US"]) == .english else { return false }
            guard AppLanguage.resolveSystemLanguage(from: ["ja-JP"]) == .english else { return false }
            return AppLanguage.resolveSystemLanguage(from: []) == .english
        }

        failures += run("default app language follows system when no override exists") {
            let isolated = makeIsolatedDefaults()
            defer { isolated.defaults.removePersistentDomain(forName: isolated.suiteName) }

            let chineseStore = SettingsStore(
                userDefaults: isolated.defaults,
                preferredLanguagesProvider: { ["zh-Hans"] }
            )
            guard chineseStore.appLanguageOverride == nil else { return false }
            guard chineseStore.effectiveAppLanguage == .chinese else { return false }

            let englishStore = SettingsStore(
                userDefaults: isolated.defaults,
                preferredLanguagesProvider: { ["fr-FR"] }
            )
            return englishStore.effectiveAppLanguage == .english
        }

        failures += run("app language override persists across reloads") {
            let isolated = makeIsolatedDefaults()
            defer { isolated.defaults.removePersistentDomain(forName: isolated.suiteName) }

            let store = SettingsStore(
                userDefaults: isolated.defaults,
                preferredLanguagesProvider: { ["ja-JP"] }
            )
            guard store.effectiveAppLanguage == .english else { return false }

            store.appLanguageOverride = .chinese
            guard store.effectiveAppLanguage == .chinese else { return false }

            let reloadedChinese = SettingsStore(
                userDefaults: isolated.defaults,
                preferredLanguagesProvider: { ["en-US"] }
            )
            guard reloadedChinese.appLanguageOverride == .chinese else { return false }
            guard reloadedChinese.effectiveAppLanguage == .chinese else { return false }

            reloadedChinese.appLanguageOverride = .english
            let reloadedEnglish = SettingsStore(
                userDefaults: isolated.defaults,
                preferredLanguagesProvider: { ["zh-Hans"] }
            )
            return reloadedEnglish.effectiveAppLanguage == .english
        }

        failures += run("app language override does not trigger timer settings callback") {
            let isolated = makeIsolatedDefaults()
            defer { isolated.defaults.removePersistentDomain(forName: isolated.suiteName) }

            let store = SettingsStore(
                userDefaults: isolated.defaults,
                preferredLanguagesProvider: { ["en-US"] }
            )
            var callbackCount = 0
            store.onDidChange = {
                callbackCount += 1
            }

            store.appLanguageOverride = .chinese
            store.appLanguageOverride = .english

            return callbackCount == 0
        }

        failures += run("localized duration labels support chinese and english") {
            let chinese = AppStrings(language: .chinese)
            let english = AppStrings(language: .english)

            guard chinese.breakDurationValue(30) == "30 秒" else { return false }
            guard chinese.breakDurationValue(60) == "1 分钟" else { return false }
            guard chinese.breakDurationValue(90) == "1分30秒" else { return false }
            guard english.breakDurationValue(30) == "30 sec" else { return false }
            guard english.breakDurationValue(60) == "1 min" else { return false }
            return english.breakDurationValue(90) == "1m 30s"
        }

        failures += run("localized session labels support chinese and english") {
            let session = RestSession(
                scheduledRestSeconds: 60,
                actualRestSeconds: 15,
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 115),
                skipped: true,
                skipReason: "esc"
            )
            let noRestSession = RestSession(
                scheduledRestSeconds: 60,
                actualRestSeconds: 0,
                startedAt: Date(timeIntervalSince1970: 200),
                endedAt: Date(timeIntervalSince1970: 200),
                skipped: true,
                skipReason: "no_rest"
            )
            let chinese = AppStrings(language: .chinese)
            let english = AppStrings(language: .english)

            guard chinese.sessionResultLabel(for: session) == "跳过 00:15" else { return false }
            guard english.sessionResultLabel(for: session) == "Skipped 00:15" else { return false }
            guard chinese.sessionResultLabel(for: noRestSession) == "不休息 00:00" else { return false }
            guard english.sessionResultLabel(for: noRestSession) == "No rest 00:00" else { return false }
            guard chinese.sessionCountLabel(3) == "3 次" else { return false }
            guard english.sessionCountLabel(3) == "3 sessions" else { return false }
            return english.noSessionsYet == "No sessions yet"
        }

        failures += run("launch at login status messages are bilingual") {
            let chinese = AppStrings(language: .chinese)
            let english = AppStrings(language: .english)

            guard chinese.launchAtLoginStatus(.setFailed) == "开机启动设置失败，请稍后重试" else { return false }
            guard english.launchAtLoginStatus(.setFailed) == "Could not update launch-at-login. Please try again." else { return false }
            guard chinese.launchAtLoginStatus(.moveToApplicationsRequired) == "请先将 Rhythm 放到“应用程序”后，再开启开机启动" else {
                return false
            }
            return english.launchAtLoginStatus(.approvalRequired) == "Requested. Please allow it in System Settings > Login Items."
        }

        failures += run("focus extension stacks without changing defaults") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 900))
            let settings = FakeSettings(focusSeconds: 10, restSeconds: 5)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(3)
            engine.processTick(now: clock.now)
            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 7 else { return false }

            engine.extendFocus(by: 5)
            guard engine.secondsUntilBreak == 12 else { return false }

            engine.extendFocus(by: 10)
            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 22 else { return false }
            return settings.focusSeconds == 10
        }

        failures += run("focus shortening brings the current break earlier") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 950))
            let settings = FakeSettings(focusSeconds: 600, restSeconds: 5)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(120)
            engine.processTick(now: clock.now)
            guard engine.secondsUntilBreak == 480 else { return false }
            guard engine.canShortenFocus(by: 300) else { return false }

            engine.shortenFocus(by: 300)

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 180 else { return false }
            return settings.focusSeconds == 600
        }

        failures += run("focus shortening is disabled when less than five minutes remain") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 975))
            let settings = FakeSettings(focusSeconds: 400, restSeconds: 5)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(150)
            engine.processTick(now: clock.now)
            guard engine.secondsUntilBreak == 250 else { return false }
            guard engine.canShortenFocus(by: 300) == false else { return false }

            engine.shortenFocus(by: 300)

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 250 else { return false }
            return overlay.lastPresentedRestSeconds == nil
        }

        failures += run("timer skip records rest session") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_000))
            let settings = FakeSettings(focusSeconds: 10, restSeconds: 5)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(10)
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }
            guard overlay.lastPresentedRestSeconds == 5 else { return false }

            clock.now = clock.now.addingTimeInterval(2)
            overlay.onSkipped?()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 10 else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 5 else { return false }
            guard sessions.captured[0].actualRestSeconds == 2 else { return false }
            guard sessions.captured[0].skipped else { return false }
            return sessions.captured[0].skipReason == "esc"
        }

        failures += run("extended rest completion stores final planned duration") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_250))
            let settings = FakeSettings(focusSeconds: 12, restSeconds: 4)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(12)
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }
            guard overlay.lastPresentedRestSeconds == 4 else { return false }

            engine.extendRest(by: 1)
            engine.extendRest(by: 5)
            guard overlay.extendCalls == [1, 5] else { return false }
            guard overlay.extendedRestSeconds == 6 else { return false }

            clock.now = clock.now.addingTimeInterval(3)
            overlay.onCompleted?()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 12 else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 10 else { return false }
            guard sessions.captured[0].actualRestSeconds == 3 else { return false }
            return sessions.captured[0].skipped == false
        }

        failures += run("extended rest skip stores final planned duration") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_400))
            let settings = FakeSettings(focusSeconds: 8, restSeconds: 4)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(8)
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }

            engine.extendRest(by: 1)
            engine.extendRest(by: 5)
            guard overlay.extendedRestSeconds == 6 else { return false }

            clock.now = clock.now.addingTimeInterval(2)
            overlay.onSkipped?()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 8 else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 10 else { return false }
            guard sessions.captured[0].actualRestSeconds == 2 else { return false }
            guard sessions.captured[0].skipped else { return false }
            return sessions.captured[0].skipReason == "esc"
        }

        failures += run("no-rest mode records auto skipped session") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_500))
            let settings = FakeSettings(focusSeconds: 12, restSeconds: 90, skipRestEnabled: true)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(12)
            engine.processTick(now: clock.now)

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 12 else { return false }
            guard overlay.lastPresentedRestSeconds == nil else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].skipped else { return false }
            guard sessions.captured[0].skipReason == "no_rest" else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 90 else { return false }
            return sessions.captured[0].actualRestSeconds == 0
        }

        failures += run("reset cycle clears focus extension") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_800))
            let settings = FakeSettings(focusSeconds: 12, restSeconds: 4)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(4)
            engine.processTick(now: clock.now)
            engine.extendFocus(by: 10)
            guard engine.secondsUntilBreak == 18 else { return false }

            engine.resetCycle()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 12 else { return false }
            return overlay.dismissCallCount == 1
        }

        failures += run("settings change keeps current focus timer and applies next cycle") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_900))
            let settings = FakeSettings(focusSeconds: 12, restSeconds: 4)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(4)
            engine.processTick(now: clock.now)
            engine.extendFocus(by: 10)
            guard engine.secondsUntilBreak == 18 else { return false }

            settings.focusSeconds = 20
            engine.processTick(now: clock.now)

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 18 else { return false }
            guard overlay.dismissCallCount == 0 else { return false }

            engine.startBreakNow()
            guard engine.mode == .resting else { return false }

            clock.now = clock.now.addingTimeInterval(2)
            overlay.onCompleted?()

            guard engine.mode == .focusing else { return false }
            return engine.secondsUntilBreak == 20
        }

        failures += run("rest setting change does not affect current rest") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_950))
            let settings = FakeSettings(focusSeconds: 8, restSeconds: 4)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(8)
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }
            guard overlay.lastPresentedRestSeconds == 4 else { return false }

            settings.restSeconds = 30
            guard overlay.lastPresentedRestSeconds == 4 else { return false }

            clock.now = clock.now.addingTimeInterval(2)
            overlay.onCompleted?()

            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 4 else { return false }
            return engine.secondsUntilBreak == 8
        }

        failures += run("rest setting change during focus applies to next rest") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_975))
            let settings = FakeSettings(focusSeconds: 8, restSeconds: 4)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(2)
            engine.processTick(now: clock.now)
            guard engine.secondsUntilBreak == 6 else { return false }

            settings.restSeconds = 30
            clock.now = clock.now.addingTimeInterval(6)
            engine.processTick(now: clock.now)

            guard engine.mode == .resting else { return false }
            return overlay.lastPresentedRestSeconds == 30
        }

        failures += run("screen lock resets cycle") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 2_000))
            let settings = FakeSettings(focusSeconds: 12, restSeconds: 4)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            clock.now = clock.now.addingTimeInterval(5)
            engine.processTick(now: clock.now)
            guard engine.secondsUntilBreak == 7 else { return false }

            engine.extendFocus(by: 10)
            guard engine.secondsUntilBreak == 17 else { return false }

            lock.fireLock()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 12 else { return false }
            return overlay.dismissCallCount == 1
        }

        if includeUI {
            failures += run("overlay smoke is visible and focusable") {
                runOverlayFocusSmokeCheck()
            }
        } else {
            print("SKIP: overlay smoke check (RHYTHM_TDD_UI=0)")
        }

        if failures == 0 {
            print("All TDD checks passed.")
            exit(0)
        } else {
            print("TDD checks failed: \(failures)")
            exit(1)
        }
    }
}

@MainActor
private func run(_ name: String, check: () -> Bool) -> Int {
    let passed = check()
    if passed {
        print("PASS: \(name)")
        return 0
    } else {
        print("FAIL: \(name)")
        return 1
    }
}

private func makeIsolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "RhythmTDD.\(UUID().uuidString)"
    return (UserDefaults(suiteName: suiteName)!, suiteName)
}

private func runOverlayFocusSmokeCheck() -> Bool {
    let cwd = FileManager.default.currentDirectoryPath
    let binaryCandidates = [
        "\(cwd)/.build/arm64-apple-macosx/debug/Rhythm",
        "\(cwd)/.build/x86_64-apple-macosx/debug/Rhythm"
    ]
    let binaryPath = binaryCandidates.first { FileManager.default.fileExists(atPath: $0) }

    var env = ProcessInfo.processInfo.environment
    env["RHYTHM_SMOKE_OVERLAY"] = "1"
    env["RHYTHM_OVERLAY_DEBUG"] = "1"

    let result: ProcessResult
    if let binaryPath {
        result = runProcess(
            executable: binaryPath,
            arguments: [],
            environment: env,
            timeout: 15
        )
    } else {
        result = runProcess(
            executable: "/bin/zsh",
            arguments: ["-lc", "swift run Rhythm"],
            environment: env,
            timeout: 40
        )
    }

    guard !result.timedOut else {
        print("overlay smoke timed out")
        return false
    }
    guard result.exitCode == 0 else {
        print("overlay smoke non-zero exit: \(result.exitCode)")
        print(result.output)
        return false
    }
    guard !result.output.localizedCaseInsensitiveContains("uncaught exception") else {
        print("overlay smoke crashed")
        print(result.output)
        return false
    }

    let requiredTokens = [
        "[RhythmSmoke] start",
        "[RhythmSmoke] trigger break",
        "[RhythmOverlay] present frame=",
        "[RhythmOverlay] post-check visible=true key=true main=true",
        "[RhythmSmoke] end"
    ]
    for token in requiredTokens where !result.output.contains(token) {
        print("missing smoke token: \(token)")
        print(result.output)
        return false
    }
    return true
}

private struct ProcessResult {
    let exitCode: Int32
    let output: String
    let timedOut: Bool
}

private func runProcess(
    executable: String,
    arguments: [String],
    environment: [String: String],
    timeout: TimeInterval
) -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        return ProcessResult(exitCode: -1, output: "failed to run \(executable): \(error)", timedOut: false)
    }

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.1)
    }

    let timedOut = process.isRunning
    if timedOut {
        process.terminate()
    }
    process.waitUntilExit()
    let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""
    return ProcessResult(exitCode: process.terminationStatus, output: output, timedOut: timedOut)
}

@MainActor
private final class FakeSettings: RhythmSettings {
    var focusSeconds: Int
    var restSeconds: Int
    var skipRestEnabled: Bool
    var onDidChange: (() -> Void)?

    init(focusSeconds: Int, restSeconds: Int, skipRestEnabled: Bool = false) {
        self.focusSeconds = focusSeconds
        self.restSeconds = restSeconds
        self.skipRestEnabled = skipRestEnabled
    }
}

@MainActor
private final class FakeSessionStore: RestSessionStoring {
    private(set) var captured: [RestSession] = []

    func add(_ session: RestSession) {
        captured.append(session)
    }
}

@MainActor
private final class FakeOverlay: RestOverlaying {
    var onSkipped: (() -> Void)?
    var onCompleted: (() -> Void)?
    private(set) var dismissCallCount = 0
    private(set) var lastPresentedRestSeconds: Int?
    private(set) var extendCalls: [Int] = []
    private(set) var extendedRestSeconds = 0

    func present(restSeconds: Int) {
        lastPresentedRestSeconds = restSeconds
        extendCalls = []
        extendedRestSeconds = 0
    }

    func extendRest(by seconds: Int) {
        extendCalls.append(seconds)
        extendedRestSeconds += seconds
    }

    func dismiss() {
        dismissCallCount += 1
    }

    func skipByEscape() {
        onSkipped?()
    }
}

@MainActor
private final class FakeLockMonitor: ScreenLockMonitoring {
    var onScreenLocked: (() -> Void)?
    func start() {}
    func stop() {}
    func fireLock() {
        onScreenLocked?()
    }
}

private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
