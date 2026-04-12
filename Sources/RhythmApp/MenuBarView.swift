import AppKit
import RhythmCore
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    private var strings: AppStrings {
        AppStrings(language: settingsStore.effectiveAppLanguage)
    }

    private var settingTitleWidth: CGFloat {
        settingsStore.effectiveAppLanguage == .english ? 82 : 68
    }

    private var currentBreakKind: BreakKind {
        timerEngine.activeBreakKind ?? .standard
    }

    private var dailySnapshot: DailyTotalsSnapshot {
        sessionStore.summary(
            activePhase: timerEngine.activeSessionSnapshot,
            dayBoundaryHour: settingsStore.dayBoundaryHour,
            now: Date()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            statusSection
            configSection
            todaySection
            sessionsSection
            actionSection
        }
        .padding(14)
        .frame(width: 392)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            RhythmBrandBadge(language: settingsStore.effectiveAppLanguage)

            Spacer(minLength: 0)

            Text(strings.phaseLabel(timerEngine.mode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )
        }
    }

    private var statusSection: some View {
        sectionContainer {
            if timerEngine.mode == .focusing {
                sectionHeading(strings.timeUntilBreakTitle)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if settingsStore.skipRestEnabled {
                            Text(strings.noRestModeDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Text(strings.countdownLabel(seconds: timerEngine.secondsUntilBreak))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    Button(strings.startBreakEarlyFiveMinutesButton) {
                        timerEngine.shortenFocus(by: 300)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!timerEngine.canShortenFocus(by: 300))

                    Button(strings.extendFocusFiveMinutesButton) {
                        timerEngine.extendFocus(by: 300)
                    }
                    .buttonStyle(.bordered)

                    Button(strings.extendFocusTenMinutesButton) {
                        timerEngine.extendFocus(by: 600)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            } else {
                sectionHeading(strings.breakInProgressTitle(for: currentBreakKind))

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(strings.breakStatusDetail(for: currentBreakKind))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(strings.countdownLabel(seconds: timerEngine.secondsRemainingInPhase))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    ForEach(currentBreakKind.extensionMinutes, id: \.self) { minutes in
                        Button(strings.extendBreakButton(minutes: minutes)) {
                            timerEngine.extendRest(by: minutes * 60)
                        }
                        .buttonStyle(.bordered)
                    }

                    if currentBreakKind.usesBlockingOverlay {
                        Text(strings.escapeToEndBreakLabel(for: currentBreakKind))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .controlSize(.small)
            }
        }
    }

    private var configSection: some View {
        sectionContainer {
            sectionHeading(strings.settingsTitle)

            compactSettingRow(
                title: strings.focusIntervalTitle,
                value: strings.focusMinutesValue(settingsStore.focusMinutes),
                canDecrease: settingsStore.focusMinutes > SettingsStore.minFocusMinutes,
                canIncrease: settingsStore.focusMinutes < SettingsStore.maxFocusMinutes,
                onDecrease: decreaseFocusDuration,
                onIncrease: increaseFocusDuration
            )

            compactSettingRow(
                title: strings.breakDurationTitle,
                value: strings.breakDurationValue(settingsStore.restSeconds),
                canDecrease: settingsStore.restSeconds > (SettingsStore.restPresetSeconds.first ?? SettingsStore.minRestSeconds),
                canIncrease: settingsStore.restSeconds < (SettingsStore.restPresetSeconds.last ?? SettingsStore.maxRestSeconds),
                onDecrease: decreaseRestDuration,
                onIncrease: increaseRestDuration
            )

            compactSettingRow(
                title: strings.dayCutoffTitle,
                value: strings.dayCutoffValue(settingsStore.dayBoundaryHour),
                canDecrease: settingsStore.dayBoundaryHour > SettingsStore.minDayBoundaryHour,
                canIncrease: settingsStore.dayBoundaryHour < SettingsStore.maxDayBoundaryHour,
                onDecrease: decreaseDayBoundaryHour,
                onIncrease: increaseDayBoundaryHour
            )

            languageSettingRow(
                title: strings.languageTitle,
                selection: Binding(
                    get: { settingsStore.effectiveAppLanguage },
                    set: { settingsStore.appLanguageOverride = $0 }
                )
            )

            toggleSettingRow(
                title: strings.noRestTitle,
                isOn: Binding(
                    get: { settingsStore.skipRestEnabled },
                    set: { settingsStore.skipRestEnabled = $0 }
                )
            )

            toggleSettingRow(
                title: strings.launchAtLoginTitle,
                isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { launchAtLoginManager.setEnabled($0) }
                ),
                disabled: launchAtLoginManager.isApplying || launchAtLoginManager.isToggleDisabled
            )

            if let statusState = launchAtLoginManager.statusState {
                Text(strings.launchAtLoginStatus(statusState))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var todaySection: some View {
        let snapshot = dailySnapshot

        return sectionContainer {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading(strings.todayTitle)
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    todayInlineMetric(
                        title: strings.todayFocusTitle,
                        value: strings.compactDurationLabel(snapshot.focusSeconds),
                        tint: .accentColor
                    )

                    todayInlineMetric(
                        title: strings.todayRestTitle,
                        value: strings.compactDurationLabel(snapshot.restSeconds),
                        tint: .orange
                    )
                }
            }

            MenuTodayBalanceBar(
                focusSeconds: snapshot.focusSeconds,
                restSeconds: snapshot.restSeconds
            )

            Button(strings.openInsightsButton) {
                openInsightsWindow()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var sessionsSection: some View {
        sectionContainer {
            HStack {
                sectionHeading(strings.recentSessionsTitle)
                Spacer()
                Text(strings.sessionCountLabel(sessionStore.sessions.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sessionStore.sessions.isEmpty {
                Text(strings.noSessionsYet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionStore.sessions.prefix(5)) { session in
                    HStack {
                        Text(timeLabel(session.startedAt))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(strings.sessionResultLabel(for: session))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(session.skipped ? .orange : .green)
                    }
                }
            }
        }
    }

    private var actionSection: some View {
        HStack(spacing: 8) {
            if timerEngine.mode == .focusing {
                Button(strings.startBreakNowButton) {
                    timerEngine.startBreakNow()
                }
                .buttonStyle(.bordered)

                Button(strings.deskBreakButton) {
                    timerEngine.startBreak(preset: .deskBreak)
                }
                .buttonStyle(.bordered)
            } else {
                Button(strings.endBreakButton(for: currentBreakKind)) {
                    timerEngine.skipBreak()
                }
                .buttonStyle(.bordered)
            }

            Button(strings.resetTimerButton) {
                timerEngine.resetCycle()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(strings.quitButton) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private func compactSettingRow(
        title: String,
        value: String,
        canDecrease: Bool,
        canIncrease: Bool,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: settingTitleWidth, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                compactAdjustButton(systemImage: "minus", enabled: canDecrease, action: onDecrease)

                Text(value)
                    .frame(width: 96, alignment: .center)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                compactAdjustButton(systemImage: "plus", enabled: canIncrease, action: onIncrease)
            }
            .frame(width: 154, alignment: .trailing)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func languageSettingRow(title: String, selection: Binding<AppLanguage>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: settingTitleWidth, alignment: .leading)

            Spacer(minLength: 0)

            Picker("", selection: selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(strings.languageOptionLabel(language))
                        .tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 166)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func toggleSettingRow(
        title: String,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: settingTitleWidth, alignment: .leading)

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(disabled)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func todayInlineMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func compactAdjustButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .semibold))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(enabled ? .secondary : .tertiary)
        .disabled(!enabled)
    }

    private func increaseFocusDuration() {
        settingsStore.focusMinutes += SettingsStore.focusMinutesStep
    }

    private func decreaseFocusDuration() {
        settingsStore.focusMinutes -= SettingsStore.focusMinutesStep
    }

    private func increaseRestDuration() {
        let options = SettingsStore.restPresetSeconds
        guard let next = options.first(where: { $0 > settingsStore.restSeconds }) else {
            settingsStore.restSeconds = options.last ?? settingsStore.restSeconds
            return
        }
        settingsStore.restSeconds = next
    }

    private func decreaseRestDuration() {
        let options = SettingsStore.restPresetSeconds
        guard let previous = options.reversed().first(where: { $0 < settingsStore.restSeconds }) else {
            settingsStore.restSeconds = options.first ?? settingsStore.restSeconds
            return
        }
        settingsStore.restSeconds = previous
    }

    private func increaseDayBoundaryHour() {
        settingsStore.dayBoundaryHour += 1
    }

    private func decreaseDayBoundaryHour() {
        settingsStore.dayBoundaryHour -= 1
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func openInsightsWindow() {
        openWindow(id: RhythmWindowID.insights.rawValue)
        NSApp.activate(ignoringOtherApps: true)
    }

    @ViewBuilder
    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
    }

    @ViewBuilder
    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
    }
}

private struct MenuTodayBalanceBar: View {
    let focusSeconds: Int
    let restSeconds: Int

    private var totalSeconds: Int {
        focusSeconds + restSeconds
    }

    var body: some View {
        GeometryReader { geometry in
            let fullWidth = geometry.size.width
            let focusFraction = totalSeconds > 0 ? CGFloat(focusSeconds) / CGFloat(totalSeconds) : 0
            let restFraction = totalSeconds > 0 ? CGFloat(restSeconds) / CGFloat(totalSeconds) : 0

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(focusSeconds > 0 ? 0.95 : 0.12))
                    .frame(width: max(0, fullWidth * focusFraction))

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.orange.opacity(restSeconds > 0 ? 0.90 : 0.12))
                    .frame(width: max(0, fullWidth * restFraction))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(height: 12)
    }
}
