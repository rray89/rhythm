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
            guard store.restSeconds == 60 else { return false }
            return store.dayBoundaryHour == 0
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
            guard store.restSeconds == 600 else { return false }

            store.restSeconds = 1_111
            guard store.restSeconds == 1_200 else { return false }

            store.dayBoundaryHour = -5
            guard store.dayBoundaryHour == 0 else { return false }

            store.dayBoundaryHour = 99
            return store.dayBoundaryHour == 23
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
            guard chinese.breakDurationValue(7_200) == "2 小时" else { return false }
            guard english.breakDurationValue(30) == "30 sec" else { return false }
            guard english.breakDurationValue(60) == "1 min" else { return false }
            guard english.breakDurationValue(90) == "1m 30s" else { return false }
            guard english.breakDurationValue(7_200) == "2 hr" else { return false }
            guard english.countdownLabel(seconds: 7_200) == "2:00:00" else { return false }
            guard chinese.countdownLabel(seconds: 7_200) == "2:00:00" else { return false }
            guard chinese.breakPresetTitle(.desk) == "桌前休息" else { return false }
            guard english.breakPresetTitle(.desk) == "Desk break" else { return false }
            guard english.breakCompletedNotificationTitle(for: .desk) == "Desk break finished" else { return false }
            guard chinese.breakCompletedNotificationBody(for: .desk) == "Rhythm 已恢复专注计时。" else { return false }
            guard chinese.dayCutoffValue(4) == "04:00" else { return false }
            guard english.weekdayTrendLabel(2) == "Mo" else { return false }
            return BreakPreset.longBreaks == [.deskBreak]
        }

        failures += run("menu bar accessibility labels are localized") {
            let chinese = AppStrings(language: .chinese)
            let english = AppStrings(language: .english)

            guard english.menuBarAccessibilityLabel(mode: .focusing, remainingSeconds: 300, breakKind: nil) == "Rhythm, Focus, 05:00 remaining" else {
                return false
            }
            guard chinese.menuBarAccessibilityLabel(mode: .focusing, remainingSeconds: 300, breakKind: nil) == "Rhythm，专注中，剩余 05:00" else {
                return false
            }
            guard english.menuBarAccessibilityLabel(mode: .resting, remainingSeconds: 45, breakKind: .standard) == "Rhythm, On Break, 00:45 remaining" else {
                return false
            }
            return chinese.menuBarAccessibilityLabel(mode: .resting, remainingSeconds: 7_200, breakKind: .desk) == "Rhythm，桌前休息，剩余 2:00:00"
        }

        failures += run("legacy rest sessions decode without a break kind or source") {
            let json = """
            [
              {
                "actualRestSeconds": 120,
                "createdAt": 1000,
                "endedAt": 1000,
                "id": "60D8C188-C1A2-4D76-B4B6-0CC448CB0F86",
                "scheduledRestSeconds": 180,
                "skipReason": null,
                "skipped": false,
                "startedAt": 880
              }
            ]
            """
            let decoder = JSONDecoder()
            guard let data = json.data(using: .utf8) else { return false }
            guard let sessions = try? decoder.decode([RestSession].self, from: data) else { return false }
            guard sessions.count == 1 else { return false }
            guard sessions[0].breakKind == .standard else { return false }
            return sessions[0].source == .timer
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

        failures += run("session store migrates legacy rest history into weekly folders") {
            let tempDirectory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: tempDirectory) }

            let calendar = makeUTCCalendar()
            let legacySession = RestSession(
                scheduledRestSeconds: 300,
                actualRestSeconds: 240,
                startedAt: makeUTCDate(year: 2026, month: 4, day: 8, hour: 9, minute: 0),
                endedAt: makeUTCDate(year: 2026, month: 4, day: 8, hour: 9, minute: 4),
                skipped: false
            )

            let encoder = JSONEncoder()
            guard let data = try? encoder.encode([legacySession]) else { return false }
            let legacyURL = tempDirectory.appendingPathComponent(SessionStore.legacyRestFileName, isDirectory: false)
            try? data.write(to: legacyURL, options: .atomic)

            let store = SessionStore(baseDirectoryURL: tempDirectory, calendar: calendar)
            guard store.sessions.count == 1 else { return false }
            guard store.restSessions.count == 1 else { return false }

            let migratedURL = tempDirectory
                .appendingPathComponent("history", isDirectory: true)
                .appendingPathComponent("weeks", isDirectory: true)
                .appendingPathComponent("2026-04-06", isDirectory: true)
                .appendingPathComponent(SessionStore.restSessionsFileName, isDirectory: false)

            guard FileManager.default.fileExists(atPath: migratedURL.path) else { return false }
            return FileManager.default.fileExists(atPath: legacyURL.path) == false
        }

        failures += run("daily totals honor cutoff live phase and short session threshold") {
            let calendar = makeUTCCalendar()
            let focusSessions = [
                FocusSession(
                    scheduledFocusSeconds: 1_200,
                    actualFocusSeconds: 1_200,
                    startedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 1, minute: 50),
                    endedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 2, minute: 10),
                    endReason: .scheduledBreak
                )
            ]
            let restSessions = [
                RestSession(
                    scheduledRestSeconds: 300,
                    actualRestSeconds: 300,
                    startedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 1, minute: 0),
                    endedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 1, minute: 5),
                    skipped: false
                ),
                RestSession(
                    scheduledRestSeconds: 8,
                    actualRestSeconds: 8,
                    startedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 2, minute: 2),
                    endedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 2, minute: 2, second: 8),
                    skipped: false
                )
            ]
            let now = makeUTCDate(year: 2026, month: 4, day: 10, hour: 2, minute: 20)
            let activePhase = ActiveSessionSnapshot(
                kind: .focus,
                startedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 2, minute: 5),
                scheduledSeconds: 3_600,
                breakKind: nil
            )

            let snapshot = DailyTotalsCalculator.snapshot(
                focusSessions: focusSessions,
                restSessions: restSessions,
                activePhase: activePhase,
                dayBoundaryHour: 2,
                now: now,
                calendar: calendar
            )

            guard snapshot.todayStartDate == makeUTCDate(year: 2026, month: 4, day: 10, hour: 2, minute: 0) else { return false }
            guard snapshot.focusSeconds == 1_500 else { return false }
            guard snapshot.restSeconds == 0 else { return false }
            guard snapshot.trendDays.count == 7 else { return false }
            guard snapshot.trendDays[5].focusSeconds == 600 else { return false }
            return snapshot.trendDays[5].restSeconds == 300
        }

        failures += run("screen lock rest stays out of recent sessions") {
            let tempDirectory = makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: tempDirectory) }

            let store = SessionStore(baseDirectoryURL: tempDirectory, calendar: makeUTCCalendar())
            store.add(restSession: RestSession(
                scheduledRestSeconds: 120,
                actualRestSeconds: 120,
                startedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0),
                endedAt: makeUTCDate(year: 2026, month: 4, day: 10, hour: 12, minute: 2),
                skipped: false,
                source: .screenLock
            ))

            guard store.restSessions.count == 1 else { return false }
            return store.sessions.isEmpty
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

        failures += run("status item countdown follows the active phase") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 925))
            let settings = FakeSettings(focusSeconds: 10, restSeconds: 4)
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
            guard engine.statusItemCountdownSeconds == 10 else { return false }

            clock.now = clock.now.addingTimeInterval(3)
            engine.processTick(now: clock.now)
            guard engine.mode == .focusing else { return false }
            guard engine.statusItemCountdownSeconds == 7 else { return false }

            clock.now = clock.now.addingTimeInterval(7)
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }
            guard engine.statusItemCountdownSeconds == 4 else { return false }

            clock.now = clock.now.addingTimeInterval(2)
            engine.processTick(now: clock.now)
            return engine.statusItemCountdownSeconds == 2
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
            guard engine.secondsRemainingInPhase == 5 else { return false }

            clock.now = clock.now.addingTimeInterval(2)
            engine.processTick(now: clock.now)
            guard engine.secondsRemainingInPhase == 3 else { return false }
            overlay.onSkipped?()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 10 else { return false }
            guard sessions.capturedFocus.count == 1 else { return false }
            guard sessions.capturedFocus[0].endReason == .scheduledBreak else { return false }
            guard sessions.capturedFocus[0].actualFocusSeconds == 10 else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].breakKind == .standard else { return false }
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
            guard overlay.updatedRemainingSeconds.suffix(2) == [5, 10] else { return false }
            guard engine.secondsRemainingInPhase == 10 else { return false }

            clock.now = clock.now.addingTimeInterval(3)
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }
            guard engine.secondsRemainingInPhase == 7 else { return false }

            clock.now = clock.now.addingTimeInterval(7)
            engine.processTick(now: clock.now)

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 12 else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].breakKind == .standard else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 10 else { return false }
            guard sessions.captured[0].actualRestSeconds == 10 else { return false }
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
            guard overlay.updatedRemainingSeconds.suffix(2) == [5, 10] else { return false }

            clock.now = clock.now.addingTimeInterval(2)
            engine.processTick(now: clock.now)
            overlay.onSkipped?()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 8 else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].breakKind == .standard else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 10 else { return false }
            guard sessions.captured[0].actualRestSeconds == 2 else { return false }
            guard sessions.captured[0].skipped else { return false }
            return sessions.captured[0].skipReason == "esc"
        }

        failures += run("manual long break preset presents kind and stores it") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_450))
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
            let preset = BreakPreset(kind: .gym, durationSeconds: 120)
            engine.startBreak(preset: preset)

            guard engine.mode == .resting else { return false }
            guard engine.activeBreakKind == .gym else { return false }
            guard overlay.lastPresentedBreakKind == .gym else { return false }
            guard overlay.lastPresentedRestSeconds == 120 else { return false }

            clock.now = clock.now.addingTimeInterval(120)
            engine.processTick(now: clock.now)

            guard engine.mode == .focusing else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].breakKind == .gym else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 120 else { return false }
            return sessions.captured[0].actualRestSeconds == 120
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
            guard sessions.captured[0].breakKind == .standard else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 90 else { return false }
            return sessions.captured[0].actualRestSeconds == 0
        }

        failures += run("manual break bypasses no-rest mode") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_650))
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
            engine.startBreakNow()

            guard engine.mode == .resting else { return false }
            guard engine.activeBreakKind == .standard else { return false }
            guard overlay.lastPresentedRestSeconds == 90 else { return false }
            guard sessions.captured.isEmpty else { return false }
            guard sessions.capturedFocus.isEmpty else { return false }
            return true
        }

        failures += run("manual break records focus session after elapsed focus time") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_675))
            let settings = FakeSettings(focusSeconds: 20, restSeconds: 90)
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
            clock.now = clock.now.addingTimeInterval(7)
            engine.processTick(now: clock.now)
            engine.startBreakNow()

            guard engine.mode == .resting else { return false }
            guard sessions.capturedFocus.count == 1 else { return false }
            guard sessions.capturedFocus[0].endReason == .manualBreak else { return false }
            guard sessions.capturedFocus[0].scheduledFocusSeconds == 20 else { return false }
            return sessions.capturedFocus[0].actualFocusSeconds == 7
        }

        failures += run("desk break stays on menu and notifies on completion") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_700))
            let settings = FakeSettings(focusSeconds: 12, restSeconds: 90)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()
            let notifier = FakeBreakNotifier()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                breakNotifier: notifier,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            let preset = BreakPreset(kind: .desk, durationSeconds: 1_200)
            engine.startBreak(preset: preset)

            guard engine.mode == .resting else { return false }
            guard engine.activeBreakKind == .desk else { return false }
            guard engine.secondsRemainingInPhase == 1_200 else { return false }
            guard overlay.visiblePresentCount == 0 else { return false }

            clock.now = clock.now.addingTimeInterval(300)
            engine.processTick(now: clock.now)
            guard engine.secondsRemainingInPhase == 900 else { return false }
            guard overlay.updatedRemainingSeconds.last == 900 else { return false }

            clock.now = clock.now.addingTimeInterval(900)
            engine.processTick(now: clock.now)

            guard engine.mode == .focusing else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].breakKind == .desk else { return false }
            guard sessions.captured[0].scheduledRestSeconds == 1_200 else { return false }
            guard notifier.notifiedKinds == [.desk] else { return false }
            return sessions.captured[0].actualRestSeconds == 1_200
        }

        failures += run("desk break can end early from the menu") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_800))
            let settings = FakeSettings(focusSeconds: 12, restSeconds: 90)
            let sessions = FakeSessionStore()
            let overlay = FakeOverlay()
            let lock = FakeLockMonitor()
            let notifier = FakeBreakNotifier()

            let engine = TimerEngine(
                settingsStore: settings,
                sessionStore: sessions,
                overlayManager: overlay,
                lockMonitor: lock,
                breakNotifier: notifier,
                nowProvider: { clock.now },
                autoStart: false,
                useSystemTimer: false
            )

            engine.start()
            let preset = BreakPreset(kind: .desk, durationSeconds: 1_200)
            engine.startBreak(preset: preset)

            clock.now = clock.now.addingTimeInterval(180)
            engine.processTick(now: clock.now)
            engine.skipBreak()

            guard engine.mode == .focusing else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].breakKind == .desk else { return false }
            guard sessions.captured[0].skipped else { return false }
            guard sessions.captured[0].skipReason == "manual" else { return false }
            return notifier.notifiedKinds.isEmpty
        }

        failures += run("screen lock during break stores timer rest plus hidden lock rest") {
            let clock = TestClock(now: Date(timeIntervalSince1970: 1_850))
            let settings = FakeSettings(focusSeconds: 5, restSeconds: 30)
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
            clock.now = clock.now.addingTimeInterval(12)
            engine.processTick(now: clock.now)

            lock.fireLock()

            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].source == .timer else { return false }
            guard sessions.captured[0].actualRestSeconds == 12 else { return false }

            clock.now = clock.now.addingTimeInterval(60)
            lock.fireUnlock()

            guard sessions.captured.count == 2 else { return false }
            guard sessions.captured[1].source == .screenLock else { return false }
            return sessions.captured[1].actualRestSeconds == 60
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
            guard sessions.capturedFocus.count == 1 else { return false }
            guard sessions.capturedFocus[0].endReason == .reset else { return false }
            guard sessions.capturedFocus[0].scheduledFocusSeconds == 22 else { return false }
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
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }
            clock.now = clock.now.addingTimeInterval(2)
            engine.processTick(now: clock.now)

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
            engine.processTick(now: clock.now)
            guard engine.mode == .resting else { return false }
            clock.now = clock.now.addingTimeInterval(2)
            engine.processTick(now: clock.now)

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

        failures += run("screen lock creates hidden rest and fresh focus after unlock") {
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

            guard sessions.capturedFocus.count == 1 else { return false }
            guard sessions.capturedFocus[0].endReason == .screenLock else { return false }
            guard sessions.capturedFocus[0].actualFocusSeconds == 5 else { return false }
            guard sessions.captured.isEmpty else { return false }
            guard overlay.dismissCallCount == 1 else { return false }

            clock.now = clock.now.addingTimeInterval(1_200)
            lock.fireUnlock()

            guard engine.mode == .focusing else { return false }
            guard engine.secondsUntilBreak == 12 else { return false }
            guard sessions.captured.count == 1 else { return false }
            guard sessions.captured[0].source == .screenLock else { return false }
            return sessions.captured[0].actualRestSeconds == 1_200
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

private func makeTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("RhythmTDD-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeUTCCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}

private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
    let calendar = makeUTCCalendar()
    return calendar.date(from: DateComponents(
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
        second: second
    ))!
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
private final class FakeSessionStore: SessionRecording {
    private(set) var captured: [RestSession] = []
    private(set) var capturedFocus: [FocusSession] = []

    func add(restSession: RestSession) {
        captured.append(restSession)
    }

    func add(focusSession: FocusSession) {
        capturedFocus.append(focusSession)
    }
}

@MainActor
private final class FakeOverlay: RestOverlaying {
    var onSkipped: (() -> Void)?
    var onExtendRequested: ((Int) -> Void)?
    private(set) var dismissCallCount = 0
    private(set) var lastPresentedRestSeconds: Int?
    private(set) var lastPresentedBreakKind: BreakKind?
    private(set) var updatedRemainingSeconds: [Int] = []
    private(set) var visiblePresentCount = 0

    func present(restSeconds: Int, breakKind: BreakKind) {
        lastPresentedRestSeconds = restSeconds
        lastPresentedBreakKind = breakKind
        updatedRemainingSeconds = [restSeconds]
        if breakKind.usesBlockingOverlay {
            visiblePresentCount += 1
        }
    }

    func updateRemaining(restSeconds: Int) {
        updatedRemainingSeconds.append(restSeconds)
    }

    func dismiss() {
        dismissCallCount += 1
    }

    func skipByEscape() {
        onSkipped?()
    }
}

@MainActor
private final class FakeBreakNotifier: BreakCompletionNotifying {
    private(set) var notifiedKinds: [BreakKind] = []

    func notifyBreakCompleted(kind: BreakKind) {
        notifiedKinds.append(kind)
    }
}

@MainActor
private final class FakeLockMonitor: ScreenLockMonitoring {
    var onScreenLocked: (() -> Void)?
    var onScreenUnlocked: (() -> Void)?
    func start() {}
    func stop() {}
    func fireLock() {
        onScreenLocked?()
    }

    func fireUnlock() {
        onScreenUnlocked?()
    }
}

private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
