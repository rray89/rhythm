import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Hashable, Identifiable {
    case chinese
    case english

    public var id: String { rawValue }

    public static func resolveSystemLanguage(from preferredLanguages: [String]) -> AppLanguage {
        guard let firstLanguage = preferredLanguages.first?.lowercased() else {
            return .english
        }
        return firstLanguage.hasPrefix("zh") ? .chinese : .english
    }
}

public enum LaunchAtLoginStatusState: Equatable {
    case setFailed
    case moveToApplicationsRequired
    case approvalRequired
    case unavailable
    case unknown
}

public struct AppStrings {
    public let language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language
    }

    public var brandSubtitle: String {
        localized(chinese: "专注与休息节奏", english: "Focus & break rhythm")
    }

    public func phaseLabel(_ mode: RhythmMode) -> String {
        switch mode {
        case .focusing:
            return localized(chinese: "专注中", english: "Focus")
        case .resting:
            return localized(chinese: "休息中", english: "Break")
        }
    }

    public var timeUntilBreakTitle: String {
        localized(chinese: "距离休息", english: "Until Break")
    }

    public var noRestModeDescription: String {
        localized(chinese: "不休息模式：到点自动跳过并记录", english: "No-rest mode: auto-skip and log")
    }

    public var breakInProgressTitle: String {
        localized(chinese: "休息进行中", english: "On Break")
    }

    public var breakOverlayShown: String {
        localized(chinese: "休息遮罩已显示", english: "Overlay active")
    }

    public var escapeToSkipLabel: String {
        localized(chinese: "ESC 跳过", english: "ESC to skip")
    }

    public var settingsTitle: String {
        localized(chinese: "节奏设置", english: "Settings")
    }

    public var focusIntervalTitle: String {
        localized(chinese: "专注间隔", english: "Focus")
    }

    public func focusMinutesValue(_ minutes: Int) -> String {
        switch language {
        case .chinese:
            return "\(minutes) 分钟"
        case .english:
            return "\(minutes) min"
        }
    }

    public var breakDurationTitle: String {
        localized(chinese: "休息时长", english: "Break")
    }

    public func breakDurationValue(_ seconds: Int) -> String {
        compactDurationLabel(seconds)
    }

    public var languageTitle: String {
        localized(chinese: "语言", english: "Language")
    }

    public func languageOptionLabel(_ language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    public var noRestTitle: String {
        localized(chinese: "不休息", english: "No Rest")
    }

    public var launchAtLoginTitle: String {
        localized(chinese: "开机启动", english: "Startup")
    }

    public func launchAtLoginStatus(_ state: LaunchAtLoginStatusState) -> String {
        switch state {
        case .setFailed:
            return localized(chinese: "开机启动设置失败，请稍后重试", english: "Could not update launch-at-login. Please try again.")
        case .moveToApplicationsRequired:
            return localized(
                chinese: "请先将 Rhythm 放到“应用程序”后，再开启开机启动",
                english: "Move Rhythm to Applications before enabling launch at login."
            )
        case .approvalRequired:
            return localized(
                chinese: "已请求开启，请在系统设置的“登录项”中允许",
                english: "Requested. Please allow it in System Settings > Login Items."
            )
        case .unavailable:
            return localized(
                chinese: "开机启动暂不可用，请重新安装后重试",
                english: "Launch at login is unavailable. Reinstall and try again."
            )
        case .unknown:
            return localized(chinese: "开机启动状态未知", english: "Launch-at-login status is unknown.")
        }
    }

    public var recentSessionsTitle: String {
        localized(chinese: "最近记录", english: "Recent Sessions")
    }

    public func sessionCountLabel(_ count: Int) -> String {
        switch language {
        case .chinese:
            return "\(count) 次"
        case .english:
            return count == 1 ? "1 session" : "\(count) sessions"
        }
    }

    public var noSessionsYet: String {
        localized(chinese: "暂无记录", english: "No sessions yet")
    }

    public var startBreakEarlyFiveMinutesButton: String {
        localized(chinese: "提前休息 5 分钟", english: "Break -5m")
    }

    public var extendFocusFiveMinutesButton: String {
        localized(chinese: "延长专注 5 分钟", english: "Focus +5m")
    }

    public var extendFocusTenMinutesButton: String {
        localized(chinese: "延长专注 10 分钟", english: "Focus +10m")
    }

    public var startBreakNowButton: String {
        localized(chinese: "立即休息", english: "Break Now")
    }

    public var skipCurrentBreakButton: String {
        localized(chinese: "跳过本次休息", english: "Skip Break")
    }

    public var resetTimerButton: String {
        localized(chinese: "重置计时", english: "Reset")
    }

    public var quitButton: String {
        localized(chinese: "退出", english: "Quit")
    }

    public var breakTimeTitle: String {
        localized(chinese: "休息时间", english: "Break Time")
    }

    public var pressEscapeToSkipBreak: String {
        localized(chinese: "按 ESC 跳过本次休息", english: "Press ESC to skip this break")
    }

    public var extendBreakOneMinuteButton: String {
        localized(chinese: "延长休息 1 分钟", english: "Break +1m")
    }

    public var extendBreakFiveMinutesButton: String {
        localized(chinese: "延长休息 5 分钟", english: "Break +5m")
    }

    public func compactDurationLabel(_ seconds: Int) -> String {
        let normalizedSeconds = max(0, seconds)
        let minutes = normalizedSeconds / 60
        let remainingSeconds = normalizedSeconds % 60

        switch language {
        case .chinese:
            if normalizedSeconds < 60 {
                return "\(normalizedSeconds) 秒"
            }
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            }
            return "\(minutes)分\(remainingSeconds)秒"
        case .english:
            if normalizedSeconds < 60 {
                return "\(normalizedSeconds) sec"
            }
            if remainingSeconds == 0 {
                return "\(minutes) min"
            }
            return "\(minutes)m \(remainingSeconds)s"
        }
    }

    public func sessionResultLabel(for session: RestSession) -> String {
        if session.skipped {
            if session.skipReason == "no_rest" {
                return localized(chinese: "不休息", english: "No rest") + " " + countdownLabel(seconds: session.actualRestSeconds)
            }
            return localized(chinese: "跳过", english: "Skipped") + " " + countdownLabel(seconds: session.actualRestSeconds)
        }
        return localized(chinese: "完成", english: "Done") + " " + countdownLabel(seconds: session.actualRestSeconds)
    }

    public func countdownLabel(seconds: Int) -> String {
        let minute = max(0, seconds) / 60
        let second = max(0, seconds) % 60
        return String(format: "%02d:%02d", minute, second)
    }

    private func localized(chinese: String, english: String) -> String {
        switch language {
        case .chinese:
            return chinese
        case .english:
            return english
        }
    }
}
