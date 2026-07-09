import AppKit
import RhythmCore
import SwiftUI

struct MenuBarView: View {
    let timerEngine: TimerEngine
    let settingsStore: SettingsStore
    let sessionStore: SessionStore
    let launchAtLoginManager: LaunchAtLoginManager
    let updater: UpdaterProviding

    @State private var visibilityState = MenuPanelVisibilityState()

    var body: some View {
        ZStack(alignment: .topLeading) {
            MenuPanelVisibilityReader { isVisible in
                visibilityState.update(windowIsVisible: isVisible)
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            switch visibilityState.renderMode {
            case .live:
                MenuBarPanelContent(
                    timerEngine: timerEngine,
                    settingsStore: settingsStore,
                    sessionStore: sessionStore,
                    launchAtLoginManager: launchAtLoginManager,
                    updater: updater
                )
            case .inert:
                MenuBarClosedPanelPlaceholder()
            }
        }
    }
}

private struct MenuBarPanelContent: View {
    @Environment(\.dismiss) private var dismissMenu
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
    let updater: UpdaterProviding
    @State private var updaterRevision = 0
    @State private var hoveredUtilityMenuItem: UtilityMenuItem?

    private var strings: AppStrings {
        AppStrings(language: settingsStore.effectiveAppLanguage)
    }

    private var settingTitleWidth: CGFloat {
        settingsStore.effectiveAppLanguage == .english ? 82 : 68
    }

    private var breakSettingTitleWidth: CGFloat {
        settingsStore.effectiveAppLanguage == .english ? 122 : 68
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
            timerActionSection
            actionSection
        }
        .padding(14)
        .frame(width: MenuBarPanelLayout.width)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(updater.objectWillChange) { _ in
            updaterRevision += 1
        }
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
                    if currentBreakKind == .desk {
                        Button(strings.shortenBreakButton(minutes: 5)) {
                            timerEngine.shortenRest(by: 300)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!timerEngine.canShortenRest(by: 300))
                    }

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

            breakDurationSettingRow

            compactSettingRow(
                title: strings.dayCutoffTitle,
                value: strings.dayCutoffValue(settingsStore.dayBoundaryHour),
                canDecrease: settingsStore.dayBoundaryHour > SettingsStore.minDayBoundaryHour,
                canIncrease: settingsStore.dayBoundaryHour < SettingsStore.maxDayBoundaryHour,
                onDecrease: decreaseDayBoundaryHour,
                onIncrease: increaseDayBoundaryHour
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
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.bottom, 4)

            utilityMenuButton(title: strings.aboutRhythmButton) {
                openAboutWindow()
            }

            if updater.isUpdateReadyToInstall {
                utilityMenuButton(title: strings.restartToUpdateButton, item: .restartToUpdate) {
                    dismissMenu()
                    updater.installUpdate()
                }
            }

            utilityMenuButton(title: strings.quitRhythmButton, shortcut: "⌘Q", item: .quit) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var timerActionSection: some View {
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
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private func utilityMenuButton(
        title: String,
        shortcut: String? = nil,
        item: UtilityMenuItem? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let item = item ?? UtilityMenuItem(title)
        let isHovered = hoveredUtilityMenuItem == item

        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15.5, weight: .regular))
                    .foregroundStyle(isHovered ? .white : .primary)

                Spacer(minLength: 12)

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isHovered ? Color.white.opacity(0.82) : Color.secondary.opacity(0.52))
                }
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredUtilityMenuItem = hovering ? item : nil
        }
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

                compactSettingValue(value)

                compactAdjustButton(systemImage: "plus", enabled: canIncrease, action: onIncrease)
            }
            .frame(width: 154, alignment: .trailing)
        }
        .font(.subheadline)
    }

    private var breakDurationSettingRow: some View {
        HStack(spacing: 10) {
            Text(strings.nextScheduledBreakRowTitle(
                usesDeskBreak: timerEngine.usesDeskBreakForNextScheduledBreak
            ))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(width: breakSettingTitleWidth, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { timerEngine.usesDeskBreakForNextScheduledBreak },
                    set: { timerEngine.setNextScheduledBreakUsesDeskBreak($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(!timerEngine.canSetNextScheduledBreakUsesDeskBreak)
                .help(strings.nextScheduledDeskBreakToggleTitle)
                .accessibilityLabel(strings.nextScheduledDeskBreakToggleTitle)

                HStack(spacing: 8) {
                    compactAdjustButton(
                        systemImage: "minus",
                        enabled: settingsStore.restSeconds > (SettingsStore.restPresetSeconds.first ?? SettingsStore.minRestSeconds),
                        action: decreaseRestDuration
                    )

                    compactSettingValue(strings.breakDurationValue(settingsStore.restSeconds))

                    compactAdjustButton(
                        systemImage: "plus",
                        enabled: settingsStore.restSeconds < (SettingsStore.restPresetSeconds.last ?? SettingsStore.maxRestSeconds),
                        action: increaseRestDuration
                    )
                }
                .frame(width: 154, alignment: .trailing)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func compactSettingValue(_ value: String, width: CGFloat = 96) -> some View {
        Text(value)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: width, alignment: .center)
            .monospacedDigit()
            .foregroundStyle(.secondary)
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
        dismissMenu()
        DispatchQueue.main.async {
            openWindow(id: RhythmWindowID.insights.rawValue)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func openAboutWindow() {
        dismissMenu()
        DispatchQueue.main.async {
            openWindow(id: RhythmWindowID.about.rawValue)
            NSApp.activate(ignoringOtherApps: true)
        }
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

private enum UtilityMenuItem: Hashable {
    case restartToUpdate
    case quit
    case title(String)

    init(_ title: String) {
        self = .title(title)
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

private struct MenuBarClosedPanelPlaceholder: View {
    var body: some View {
        Color.clear
            .frame(width: MenuBarPanelLayout.width, height: MenuBarPanelLayout.closedPlaceholderHeight)
            .fixedSize()
            .accessibilityHidden(true)
    }
}

private enum MenuBarPanelLayout {
    static let width: CGFloat = 392
    static let closedPlaceholderHeight: CGFloat = 724
}

private struct MenuPanelVisibilityReader: NSViewRepresentable {
    let onVisibilityChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVisibilityChange: onVisibilityChange)
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        context.coordinator.onVisibilityChange = onVisibilityChange
        nsView.coordinator = context.coordinator
        context.coordinator.attach(to: nsView.window)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onVisibilityChange: (Bool) -> Void
        private weak var window: NSWindow?
        private var lastPublishedVisibility: Bool?
        private var hasPendingDeferredPublish = false

        init(onVisibilityChange: @escaping (Bool) -> Void) {
            self.onVisibilityChange = onVisibilityChange
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to newWindow: NSWindow?) {
            guard window !== newWindow else {
                publishVisibilityDeferred()
                return
            }

            removeObservers()
            window = newWindow

            guard let newWindow else {
                publishVisibilityDeferred()
                return
            }

            let names: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.didBecomeMainNotification,
                NSWindow.didResignMainNotification,
                NSWindow.didChangeOcclusionStateNotification,
                NSWindow.willCloseNotification,
                NSWindow.didMiniaturizeNotification,
                NSWindow.didDeminiaturizeNotification
            ]

            for name in names {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowVisibilityDidChange(_:)),
                    name: name,
                    object: newWindow
                )
            }

            publishVisibilityDeferred()
        }

        private func removeObservers() {
            NotificationCenter.default.removeObserver(self)
            lastPublishedVisibility = nil
            hasPendingDeferredPublish = false
        }

        private func publishVisibilityDeferred() {
            guard !hasPendingDeferredPublish else { return }

            hasPendingDeferredPublish = true
            Task { @MainActor in
                hasPendingDeferredPublish = false
                publishVisibility()
            }
        }

        private func publishVisibility() {
            let isVisible = window?.isVisible == true
            guard lastPublishedVisibility != isVisible else { return }

            lastPublishedVisibility = isVisible
            onVisibilityChange(isVisible)
        }

        @objc
        private func windowVisibilityDidChange(_ notification: Notification) {
            _ = notification
            publishVisibility()
            publishVisibilityDeferred()
        }
    }

    final class TrackingView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attach(to: window)
        }
    }
}
