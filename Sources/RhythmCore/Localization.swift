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
        case .desk:
            return localized(chinese: "可继续用电脑，但别工作", english: "Stay on your Mac, just not for work")
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

    public var todayTitle: String {
        localized(chinese: "今日总量", english: "Today")
    }

    public var todayFocusTitle: String {
        localized(chinese: "专注", english: "Focus")
    }

    public var todayRestTitle: String {
        localized(chinese: "休息", english: "Rest")
    }

    public var insightsTitle: String {
        localized(chinese: "数据概览", english: "Insights")
    }

    public var openInsightsButton: String {
        localized(chinese: "打开数据概览", english: "Open Insights")
    }

    public var last7DaysTitle: String {
        localized(chinese: "最近 7 天", english: "Last 7 Days")
    }

    public var last30DaysTitle: String {
        localized(chinese: "最近 30 天", english: "Last 30 Days")
    }

    public var allTimeTitle: String {
        localized(chinese: "全部历史", english: "All Time")
    }

    public var historySessionsTitle: String {
        localized(chinese: "全部记录", english: "Sessions")
    }

    public var showHiddenRestTitle: String {
        localized(chinese: "显示隐藏休息", english: "Show Hidden Rest")
    }

    public var filterAllTitle: String {
        localized(chinese: "全部", english: "All")
    }

    public var filterFocusTitle: String {
        localized(chinese: "专注", english: "Focus")
    }

    public var filterRestTitle: String {
        localized(chinese: "休息", english: "Rest")
    }

    public var exportTitle: String {
        localized(chinese: "导出", english: "Export")
    }

    public func exportFormatTitle(_ format: HistoryExportFormat) -> String {
        switch format {
        case .csv:
            return "CSV"
        case .json:
            return "JSON"
        }
    }

    public func exportScopeTitle(_ scope: HistoryDisplayRange) -> String {
        switch scope {
        case .today:
            return todayTitle
        case .last7Days:
            return last7DaysTitle
        case .last30Days:
            return last30DaysTitle
        case .allTime:
            return allTimeTitle
        }
    }

    public func exportScopeTitle(_ scope: HistoryExportScope, reportingDayLabel: String? = nil) -> String {
        switch scope {
        case .today:
            return todayTitle
        case .last7Days:
            return last7DaysTitle
        case .last30Days:
            return last30DaysTitle
        case .allTime:
            return allTimeTitle
        case .reportingDay:
            if let reportingDayLabel {
                return selectedDayExportTitle(reportingDayLabel)
            }
            return localized(chinese: "所选日期", english: "Selected Day")
        }
    }

    public func selectedDayExportTitle(_ dateLabel: String) -> String {
        switch language {
        case .chinese:
            return "所选日期（\(dateLabel)）"
        case .english:
            return "Selected Day (\(dateLabel))"
        }
    }

    public func exportMenuLabel(title: String, count: Int) -> String {
        "\(title) (\(count))"
    }

    public var totalTitle: String {
        localized(chinese: "总量", english: "Total")
    }

    public var actualTitle: String {
        localized(chinese: "实际", english: "Actual")
    }

    public var plannedTitle: String {
        localized(chinese: "计划", english: "Planned")
    }

    public var hiddenRestTitle: String {
        localized(chinese: "隐藏休息", english: "Hidden rest")
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

    public var nextScheduledDeskBreakToggleTitle: String {
        localized(chinese: "下次桌前休息", english: "Next Desk break")
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

    public var dayCutoffTitle: String {
        localized(chinese: "日切换点", english: "Day cutoff")
    }

    public func dayCutoffValue(_ hour: Int) -> String {
        String(format: "%02d:00", max(0, min(23, hour)))
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

    public var noHistoryYet: String {
        localized(chinese: "暂无历史记录", english: "No history yet")
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

    public var deskBreakButton: String {
        localized(chinese: "桌前休息", english: "Desk break")
    }

    public var switchToDeskBreakButton: String {
        localized(chinese: "改为桌前休息", english: "Switch to Desk break")
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
        case .desk:
            return localized(chinese: "桌前休息", english: "Desk break")
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
        case .desk:
            return localized(chinese: "桌前休息", english: "Desk Break")
        }
    }

    public func menuBarAccessibilityLabel(
        mode: RhythmMode,
        remainingSeconds: Int,
        breakKind: BreakKind?
    ) -> String {
        let phase = menuBarPhaseAccessibilityLabel(mode: mode, breakKind: breakKind)
        let countdown = countdownLabel(seconds: remainingSeconds)

        switch language {
        case .chinese:
            return "Rhythm，\(phase)，剩余 \(countdown)"
        case .english:
            return "Rhythm, \(phase), \(countdown) remaining"
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

    public func shortenBreakButton(minutes: Int) -> String {
        switch language {
        case .chinese:
            return "缩短 \(minutes) 分钟"
        case .english:
            return "Break -\(minutes)m"
        }
    }

    public func breakCompletedNotificationTitle(for kind: BreakKind) -> String {
        switch kind {
        case .desk:
            return localized(chinese: "桌前休息结束", english: "Desk break finished")
        case .standard:
            return localized(chinese: "休息结束", english: "Break finished")
        case .meal:
            return localized(chinese: "用餐休息结束", english: "Meal break finished")
        case .gym:
            return localized(chinese: "健身休息结束", english: "Gym break finished")
        case .nap:
            return localized(chinese: "小憩结束", english: "Nap break finished")
        case .errand:
            return localized(chinese: "外出休息结束", english: "Errand break finished")
        }
    }

    public func breakCompletedNotificationBody(for kind: BreakKind) -> String {
        switch kind {
        case .desk:
            return localized(chinese: "Rhythm 已恢复专注计时。", english: "Rhythm has resumed focus time.")
        case .standard, .meal, .gym, .nap, .errand:
            return localized(chinese: "Rhythm 已恢复专注计时。", english: "Rhythm has resumed focus time.")
        }
    }

    public var focusEndingSoonNotificationTitle: String {
        localized(chinese: "还有 5 分钟进入休息", english: "Break starts in 5 minutes")
    }

    public func focusEndingSoonNotificationBody(remainingSeconds: Int) -> String {
        localized(
            chinese: "当前专注还剩 \(compactDurationLabel(remainingSeconds))。",
            english: "Your current focus has \(compactDurationLabel(remainingSeconds)) remaining."
        )
    }

    public func breakEndingSoonNotificationTitle(for kind: BreakKind) -> String {
        switch kind {
        case .desk:
            return localized(chinese: "桌前休息还剩 5 分钟", english: "Desk break ends in 5 minutes")
        case .standard, .meal, .gym, .nap, .errand:
            return localized(chinese: "休息还剩 5 分钟", english: "Break ends in 5 minutes")
        }
    }

    public func breakEndingSoonNotificationBody(for kind: BreakKind, remainingSeconds: Int) -> String {
        switch kind {
        case .desk:
            return localized(
                chinese: "当前桌前休息还剩 \(compactDurationLabel(remainingSeconds))。",
                english: "Your current Desk break has \(compactDurationLabel(remainingSeconds)) remaining."
            )
        case .standard, .meal, .gym, .nap, .errand:
            return localized(
                chinese: "当前休息还剩 \(compactDurationLabel(remainingSeconds))。",
                english: "Your current break has \(compactDurationLabel(remainingSeconds)) remaining."
            )
        }
    }

    public func weekdayTrendLabel(_ weekday: Int) -> String {
        switch language {
        case .chinese:
            switch weekday {
            case 1:
                return "日"
            case 2:
                return "一"
            case 3:
                return "二"
            case 4:
                return "三"
            case 5:
                return "四"
            case 6:
                return "五"
            default:
                return "六"
            }
        case .english:
            switch weekday {
            case 1:
                return "Su"
            case 2:
                return "Mo"
            case 3:
                return "Tu"
            case 4:
                return "We"
            case 5:
                return "Th"
            case 6:
                return "Fr"
            default:
                return "Sa"
            }
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

    public func historySessionKindTitle(_ kind: HistorySessionKind) -> String {
        switch kind {
        case .focus:
            return todayFocusTitle
        case .rest:
            return todayRestTitle
        }
    }

    public func restSourceTitle(_ source: RestSessionSource) -> String {
        switch source {
        case .timer:
            return localized(chinese: "计时休息", english: "Timer break")
        case .screenLock:
            return localized(chinese: "锁屏", english: "Screen lock")
        case .systemSleep:
            return localized(chinese: "系统睡眠", english: "System sleep")
        case .appDowntime:
            return localized(chinese: "应用关闭", english: "App downtime")
        }
    }

    public func focusEndReasonTitle(_ reason: FocusEndReason) -> String {
        switch reason {
        case .scheduledBreak:
            return localized(chinese: "到点进入休息", english: "Scheduled break")
        case .manualBreak:
            return localized(chinese: "手动开始休息", english: "Manual break")
        case .reset:
            return localized(chinese: "手动重置", english: "Timer reset")
        case .screenLock:
            return localized(chinese: "锁屏", english: "Screen lock")
        case .systemSleep:
            return localized(chinese: "系统睡眠", english: "System sleep")
        case .appExit:
            return localized(chinese: "退出应用", english: "App quit")
        }
    }

    public func restStateTitle(skipped: Bool, skipReason: String?) -> String {
        if skipped {
            if skipReason == "no_rest" {
                return localized(chinese: "不休息模式", english: "No-rest mode")
            }
            return localized(chinese: "提前结束", english: "Ended early")
        }
        return localized(chinese: "完成", english: "Completed")
    }

    public func actualDurationCaption(_ duration: String) -> String {
        switch language {
        case .chinese:
            return "实际 \(duration)"
        case .english:
            return "Actual \(duration)"
        }
    }

    public func plannedDurationCaption(_ duration: String) -> String {
        switch language {
        case .chinese:
            return "计划 \(duration)"
        case .english:
            return "Planned \(duration)"
        }
    }

    public func totalDurationCaption(_ duration: String) -> String {
        switch language {
        case .chinese:
            return "总量 \(duration)"
        case .english:
            return "Total \(duration)"
        }
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

    private func menuBarPhaseAccessibilityLabel(mode: RhythmMode, breakKind: BreakKind?) -> String {
        switch mode {
        case .focusing:
            return phaseLabel(.focusing)
        case .resting:
            return breakInProgressTitle(for: breakKind ?? .standard)
        }
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
