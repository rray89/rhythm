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

    public func breakInProgressTitle(for kind: BreakKind) -> String {
        switch kind {
        case .standard:
            return breakInProgressTitle
        default:
            return activeBreakTitle(for: kind)
        }
    }

    public var breakOverlayShown: String {
        localized(chinese: "休息遮罩已显示", english: "Overlay active")
    }

    public func breakStatusDetail(for kind: BreakKind) -> String {
        switch kind {
        case .standard:
            return breakOverlayShown
        case .meal:
            return localized(chinese: "用餐休息进行中", english: "Meal break active")
        case .gym:
            return localized(chinese: "健身休息进行中", english: "Gym break active")
        case .nap:
            return localized(chinese: "小憩进行中", english: "Nap break active")
        case .errand:
            return localized(chinese: "外出休息进行中", english: "Errand break active")
        case .duolingo:
            return localized(chinese: "多邻国休息进行中", english: "Duolingo break active")
        case .walk:
            return localized(chinese: "散步休息进行中", english: "Walk break active")
        }
    }

    public var escapeToSkipLabel: String {
        localized(chinese: "ESC 跳过", english: "ESC to skip")
    }

    public func escapeToEndBreakLabel(for kind: BreakKind) -> String {
        switch kind {
        case .standard:
            return escapeToSkipLabel
        default:
            return localized(chinese: "ESC 提前结束", english: "ESC to end early")
        }
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

    public var longBreaksTitle: String {
        localized(chinese: "长休息", english: "Long Breaks")
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

    public func breakPresetTitle(_ kind: BreakKind) -> String {
        switch kind {
        case .standard:
            return localized(chinese: "普通休息", english: "Break")
        case .meal:
            return localized(chinese: "用餐", english: "Meal")
        case .gym:
            return localized(chinese: "健身", english: "Gym")
        case .nap:
            return localized(chinese: "小憩", english: "Nap")
        case .errand:
            return localized(chinese: "外出", english: "Errand")
        case .duolingo:
            return localized(chinese: "多邻国", english: "Duolingo")
        case .walk:
            return localized(chinese: "散步", english: "Walk")
        }
    }

    public var skipCurrentBreakButton: String {
        localized(chinese: "跳过本次休息", english: "Skip Break")
    }

    public func endBreakButton(for kind: BreakKind) -> String {
        switch kind {
        case .standard:
            return skipCurrentBreakButton
        default:
            return localized(chinese: "提前结束休息", english: "End Break Early")
        }
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

    public func activeBreakTitle(for kind: BreakKind) -> String {
        switch kind {
        case .standard:
            return breakTimeTitle
        case .meal:
            return localized(chinese: "用餐时间", english: "Meal Break")
        case .gym:
            return localized(chinese: "健身时间", english: "Gym Break")
        case .nap:
            return localized(chinese: "小憩时间", english: "Nap Break")
        case .errand:
            return localized(chinese: "外出时间", english: "Errand Break")
        case .duolingo:
            return localized(chinese: "多邻国时间", english: "Duolingo Break")
        case .walk:
            return localized(chinese: "散步时间", english: "Walk Break")
        }
    }

    public func pressEscapeToEndBreak(for kind: BreakKind) -> String {
        switch kind {
        case .standard:
            return pressEscapeToSkipBreak
        default:
            return localized(chinese: "按 ESC 提前结束休息", english: "Press ESC to end this break early")
        }
    }

    public var extendBreakOneMinuteButton: String {
        localized(chinese: "延长休息 1 分钟", english: "Break +1m")
    }

    public var extendBreakFiveMinutesButton: String {
        localized(chinese: "延长休息 5 分钟", english: "Break +5m")
    }

    public func extendBreakButton(minutes: Int) -> String {
        switch language {
        case .chinese:
            return "延长 \(minutes) 分钟"
        case .english:
            return "Break +\(minutes)m"
        }
    }

    public func compactDurationLabel(_ seconds: Int) -> String {
        let normalizedSeconds = max(0, seconds)
        let hours = normalizedSeconds / 3_600
        let minutes = normalizedSeconds / 60
        let remainingMinutes = (normalizedSeconds % 3_600) / 60
        let remainingSeconds = normalizedSeconds % 60

        switch language {
        case .chinese:
            if normalizedSeconds < 60 {
                return "\(normalizedSeconds) 秒"
            }
            if hours > 0 {
                if remainingMinutes == 0, remainingSeconds == 0 {
                    return "\(hours) 小时"
                }
                if remainingSeconds == 0 {
                    return "\(hours)小时\(remainingMinutes)分"
                }
                return "\(hours)小时\(remainingMinutes)分\(remainingSeconds)秒"
            }
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            }
            return "\(minutes)分\(remainingSeconds)秒"
        case .english:
            if normalizedSeconds < 60 {
                return "\(normalizedSeconds) sec"
            }
            if hours > 0 {
                if remainingMinutes == 0, remainingSeconds == 0 {
                    return "\(hours) hr"
                }
                if remainingSeconds == 0 {
                    return "\(hours)h \(remainingMinutes)m"
                }
                return "\(hours)h \(remainingMinutes)m \(remainingSeconds)s"
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
        let normalizedSeconds = max(0, seconds)
        let hours = normalizedSeconds / 3_600
        let minutes = (normalizedSeconds % 3_600) / 60
        let seconds = normalizedSeconds % 60

        if hours > 0 {
            return String(format: "%01d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
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
