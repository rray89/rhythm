import AppKit
import RhythmCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    private var strings: AppStrings {
        AppStrings(language: settingsStore.effectiveAppLanguage)
    }

    private var settingTitleWidth: CGFloat {
        settingsStore.effectiveAppLanguage == .english ? 78 : 64
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            statusSection
            configSection
            sessionsSection
            actionSection
        }
        .padding(14)
        .frame(width: 368)
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
                sectionHeading(strings.breakInProgressTitle)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(strings.breakOverlayShown)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(strings.escapeToSkipLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
            } else {
                Button(strings.skipCurrentBreakButton) {
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

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
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
