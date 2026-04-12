import AppKit
import RhythmCore
import SwiftUI
import UniformTypeIdentifiers

private enum InsightsSessionFilter: String, CaseIterable, Identifiable {
    case all
    case focus
    case rest

    var id: String { rawValue }
}

private struct InsightsInlineMetric: Identifiable {
    let title: String
    let value: String
    let tint: Color

    var id: String { title }
}

private struct InsightsExportOption: Identifiable {
    let scope: HistoryExportScope
    let title: String
    let count: Int

    var id: String {
        switch scope {
        case .today:
            return "today"
        case .last7Days:
            return "last7Days"
        case .last30Days:
            return "last30Days"
        case .allTime:
            return "allTime"
        case let .reportingDay(startDate):
            return "reportingDay-\(startDate.timeIntervalSince1970)"
        }
    }
}

struct InsightsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore

    @State private var sessionFilter: InsightsSessionFilter = .all
    @State private var showHiddenRest = false
    @State private var selectedSessionDay: Date?
    @State private var exportErrorMessage: String?

    private var strings: AppStrings {
        AppStrings(language: settingsStore.effectiveAppLanguage)
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var snapshot: HistoryInsightsSnapshot {
        sessionStore.insights(
            activePhase: timerEngine.activeSessionSnapshot,
            dayBoundaryHour: settingsStore.dayBoundaryHour,
            now: Date()
        )
    }

    private var currentReportingDayStart: Date {
        snapshot.today.startDate
    }

    private var dayNavigableEntries: [HistorySessionEntry] {
        snapshot.sessionEntries.filter { entry in
            showHiddenRest || !entry.isHiddenRest
        }
    }

    private var availableSessionDays: [Date] {
        Array(Set(dayNavigableEntries.map(\.reportingDayStart))).sorted(by: >)
    }

    private var preferredSelectedSessionDay: Date? {
        if availableSessionDays.contains(currentReportingDayStart) {
            return currentReportingDayStart
        }
        return availableSessionDays.first
    }

    private var resolvedSelectedSessionDay: Date? {
        if let selectedSessionDay, availableSessionDays.contains(selectedSessionDay) {
            return selectedSessionDay
        }
        return preferredSelectedSessionDay
    }

    private var selectedDayEntries: [HistorySessionEntry] {
        guard let resolvedSelectedSessionDay else {
            return []
        }

        return dayNavigableEntries.filter { $0.reportingDayStart == resolvedSelectedSessionDay }
    }

    private var filteredSelectedDayEntries: [HistorySessionEntry] {
        selectedDayEntries.filter { entry in
            switch sessionFilter {
            case .all:
                return true
            case .focus:
                return entry.kind == .focus
            case .rest:
                return entry.kind == .rest
            }
        }
    }

    private var selectedDayIndex: Int? {
        guard let resolvedSelectedSessionDay else {
            return nil
        }
        return availableSessionDays.firstIndex(of: resolvedSelectedSessionDay)
    }

    private var canSelectNewerDay: Bool {
        guard let selectedDayIndex else {
            return false
        }
        return selectedDayIndex > 0
    }

    private var canSelectOlderDay: Bool {
        guard let selectedDayIndex else {
            return false
        }
        return selectedDayIndex < availableSessionDays.count - 1
    }

    private var exportOptions: [InsightsExportOption] {
        exportScopes.map { scope in
            let preview = sessionStore.exportPreview(
                scope: scope,
                dayBoundaryHour: settingsStore.dayBoundaryHour,
                now: snapshot.generatedAt
            )
            return InsightsExportOption(
                scope: preview.scope,
                title: exportTitle(for: preview.scope),
                count: preview.sessionCount
            )
        }
    }

    private var exportScopes: [HistoryExportScope] {
        var scopes: [HistoryExportScope] = [
            .today,
            .last7Days,
            .last30Days,
            .allTime,
        ]

        if let resolvedSelectedSessionDay,
           resolvedSelectedSessionDay != currentReportingDayStart {
            scopes.append(.reportingDay(startDate: resolvedSelectedSessionDay))
        }

        return scopes
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerSection
                todaySection
                trendSection(
                    title: strings.last7DaysTitle,
                    snapshot: snapshot.last7Days,
                    labelStyle: .weekday
                )
                trendSection(
                    title: strings.last30DaysTitle,
                    snapshot: snapshot.last30Days,
                    labelStyle: .dayOfMonthCompressed
                )
                trendSection(
                    title: strings.allTimeTitle,
                    snapshot: snapshot.allTime,
                    labelStyle: .monthDayCompressed
                )
                sessionsSection
                exportSection
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: syncSelectedSessionDay)
        .onChange(of: availableSessionDays) { _ in
            syncSelectedSessionDay()
        }
        .onChange(of: currentReportingDayStart) { _ in
            syncSelectedSessionDay()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(strings.insightsTitle)
                .font(.title2.weight(.semibold))

            Spacer(minLength: 0)

            Text(dayCutoffDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var todaySection: some View {
        let today = snapshot.today

        return sectionContainer {
            InsightsSectionHeader(
                title: strings.todayTitle,
                detail: dayCutoffDetail,
                metrics: metrics(for: today)
            )

            TodayBalanceBar(
                focusSeconds: today.focusSeconds,
                restSeconds: today.restSeconds,
                strings: strings
            )
        }
    }

    @ViewBuilder
    private func trendSection(
        title: String,
        snapshot: HistoryRangeSnapshot,
        labelStyle: TrendAxisLabelStyle
    ) -> some View {
        sectionContainer {
            InsightsSectionHeader(
                title: title,
                detail: rangeLabel(for: snapshot),
                metrics: metrics(for: snapshot)
            )

            TrendBucketsView(
                buckets: snapshot.trendBuckets,
                labelStyle: labelStyle,
                strings: strings,
                calendar: calendar
            )
        }
    }

    private var sessionsSection: some View {
        sectionContainer {
            HStack(alignment: .center, spacing: 12) {
                sectionHeading(strings.historySessionsTitle)

                Spacer(minLength: 0)

                Toggle(strings.showHiddenRestTitle, isOn: $showHiddenRest)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
            }

            if availableSessionDays.isEmpty {
                Text(strings.noHistoryYet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let resolvedSelectedSessionDay {
                SessionDayStripView(
                    days: availableSessionDays,
                    selectedDay: resolvedSelectedSessionDay,
                    canSelectNewerDay: canSelectNewerDay,
                    canSelectOlderDay: canSelectOlderDay,
                    strings: strings,
                    calendar: calendar,
                    locale: displayLocale,
                    selectNewerDay: selectNewerDay,
                    selectOlderDay: selectOlderDay,
                    selectDay: { selectedSessionDay = $0 }
                )

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dayHeaderLabel(for: resolvedSelectedSessionDay))
                            .font(.subheadline.weight(.semibold))

                        Text(strings.sessionCountLabel(filteredSelectedDayEntries.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Picker("", selection: $sessionFilter) {
                        Text(strings.filterAllTitle).tag(InsightsSessionFilter.all)
                        Text(strings.filterFocusTitle).tag(InsightsSessionFilter.focus)
                        Text(strings.filterRestTitle).tag(InsightsSessionFilter.rest)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                if filteredSelectedDayEntries.isEmpty {
                    Text(strings.noSessionsYet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredSelectedDayEntries.enumerated()), id: \.element.id) { item in
                            SessionRowView(
                                entry: item.element,
                                strings: strings,
                                dateTimeLabel: timeRangeLabel(for: item.element),
                                summaryLabel: sessionSummaryLabel(for: item.element)
                            )

                            if item.offset < filteredSelectedDayEntries.count - 1 {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
    }

    private var exportSection: some View {
        sectionContainer {
            HStack {
                sectionHeading(strings.exportTitle)
                Spacer(minLength: 0)

                Menu(strings.exportTitle) {
                    exportMenuSection(for: .csv)
                    exportMenuSection(for: .json)
                }
                .menuStyle(.borderlessButton)
            }

            if let exportErrorMessage {
                Text(exportErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func exportMenuSection(for format: HistoryExportFormat) -> some View {
        Section(strings.exportFormatTitle(format)) {
            ForEach(exportOptions) { option in
                Button(strings.exportMenuLabel(title: option.title, count: option.count)) {
                    export(scope: option.scope, format: format)
                }
            }
        }
    }

    private func export(scope: HistoryExportScope, format: HistoryExportFormat) {
        do {
            let payload = try sessionStore.exportHistory(
                scope: scope,
                format: format,
                dayBoundaryHour: settingsStore.dayBoundaryHour,
                now: Date()
            )
            let didSave = try InsightsExportController.save(payload: payload)
            exportErrorMessage = didSave ? nil : exportErrorMessage
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func exportTitle(for scope: HistoryExportScope) -> String {
        switch scope {
        case .today, .last7Days, .last30Days, .allTime:
            return strings.exportScopeTitle(scope)
        case let .reportingDay(startDate):
            return strings.exportScopeTitle(
                scope,
                reportingDayLabel: shortDayLabel(for: startDate)
            )
        }
    }

    private func metrics(for snapshot: HistoryRangeSnapshot) -> [InsightsInlineMetric] {
        [
            InsightsInlineMetric(
                title: strings.todayFocusTitle,
                value: strings.compactDurationLabel(snapshot.focusSeconds),
                tint: .accentColor
            ),
            InsightsInlineMetric(
                title: strings.todayRestTitle,
                value: strings.compactDurationLabel(snapshot.restSeconds),
                tint: .orange
            ),
            InsightsInlineMetric(
                title: strings.totalTitle,
                value: strings.compactDurationLabel(snapshot.focusSeconds + snapshot.restSeconds),
                tint: .secondary
            ),
        ]
    }

    private var dayCutoffDetail: String {
        "\(strings.dayCutoffTitle): \(strings.dayCutoffValue(settingsStore.dayBoundaryHour))"
    }

    private func rangeLabel(for snapshot: HistoryRangeSnapshot) -> String {
        let endDate = snapshot.endDate.addingTimeInterval(-1)
        return "\(rangeBoundaryLabel(for: snapshot.startDate, compareTo: endDate)) - \(rangeBoundaryLabel(for: endDate, compareTo: snapshot.startDate))"
    }

    private func rangeBoundaryLabel(for date: Date, compareTo otherDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = displayLocale
        formatter.timeZone = calendar.timeZone

        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: otherDate)
        if strings.language == .chinese {
            formatter.setLocalizedDateFormatFromTemplate(sameYear ? "M月d日" : "y年M月d日")
        } else {
            formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMM d" : "MMM d, y")
        }

        return formatter.string(from: date)
    }

    private func sessionSummaryLabel(for entry: HistorySessionEntry) -> String {
        var parts: [String] = []

        switch entry.kind {
        case .focus:
            if let focusEndReason = entry.focusEndReason {
                parts.append(strings.focusEndReasonTitle(focusEndReason))
            }
        case .rest:
            parts.append(strings.restStateTitle(skipped: entry.skipped, skipReason: entry.skipReason))

            if let restSource = entry.restSource, restSource != .timer {
                parts.append(strings.restSourceTitle(restSource))
            } else if let breakKind = entry.breakKind {
                parts.append(strings.breakPresetTitle(breakKind))
            }

            if entry.isHiddenRest {
                parts.append(strings.hiddenRestTitle)
            }
        }

        parts.append(strings.actualDurationCaption(strings.compactDurationLabel(entry.actualSeconds)))

        if entry.scheduledSeconds != entry.actualSeconds {
            parts.append(strings.plannedDurationCaption(strings.compactDurationLabel(entry.scheduledSeconds)))
        }

        return parts.joined(separator: " • ")
    }

    private func timeRangeLabel(for entry: HistorySessionEntry) -> String {
        let start = timeLabel(entry.startedAt)
        let end = timeLabel(entry.endedAt)
        return "\(start) - \(end)"
    }

    private func dayHeaderLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = displayLocale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(strings.language == .chinese ? "M月d日EEE" : "EEE, MMM d")
        return formatter.string(from: date)
    }

    private func shortDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = displayLocale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(strings.language == .chinese ? "M月d日" : "MMM d")
        return formatter.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = displayLocale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var displayLocale: Locale {
        switch strings.language {
        case .chinese:
            return Locale(identifier: "zh_CN")
        case .english:
            return Locale(identifier: "en_US_POSIX")
        }
    }

    @ViewBuilder
    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
    }

    @ViewBuilder
    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
    }

    private func syncSelectedSessionDay() {
        guard let preferredSelectedSessionDay else {
            selectedSessionDay = nil
            return
        }

        guard let selectedSessionDay else {
            self.selectedSessionDay = preferredSelectedSessionDay
            return
        }

        if !availableSessionDays.contains(selectedSessionDay) {
            self.selectedSessionDay = preferredSelectedSessionDay
        }
    }

    private func selectNewerDay() {
        guard let selectedDayIndex, canSelectNewerDay else {
            return
        }

        selectedSessionDay = availableSessionDays[selectedDayIndex - 1]
    }

    private func selectOlderDay() {
        guard let selectedDayIndex, canSelectOlderDay else {
            return
        }

        selectedSessionDay = availableSessionDays[selectedDayIndex + 1]
    }
}

private struct InsightsSectionHeader: View {
    let title: String
    let detail: String
    let metrics: [InsightsInlineMetric]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                leadingBlock
                Spacer(minLength: 12)
                metricsRow(alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                leadingBlock
                metricsRow(alignment: .leading)
            }
        }
    }

    private var leadingBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.semibold))

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func metricsRow(alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 18) {
            ForEach(metrics) { metric in
                VStack(alignment: alignment, spacing: 2) {
                    Text(metric.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(metric.tint)

                    Text(metric.value)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct SessionDayStripView: View {
    let days: [Date]
    let selectedDay: Date
    let canSelectNewerDay: Bool
    let canSelectOlderDay: Bool
    let strings: AppStrings
    let calendar: Calendar
    let locale: Locale
    let selectNewerDay: () -> Void
    let selectOlderDay: () -> Void
    let selectDay: (Date) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: selectNewerDay) {
                Image(systemName: "chevron.left")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(!canSelectNewerDay)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(days, id: \.self) { day in
                            SessionDayChip(
                                weekdayLabel: weekdayLabel(for: day),
                                dateLabel: shortDateLabel(for: day),
                                isSelected: day == selectedDay,
                                selectDay: { selectDay(day) }
                            )
                            .id(day)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .onAppear {
                    proxy.scrollTo(selectedDay, anchor: .center)
                }
                .onChange(of: selectedDay) { day in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(day, anchor: .center)
                    }
                }
            }

            Button(action: selectOlderDay) {
                Image(systemName: "chevron.right")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(!canSelectOlderDay)
        }
    }

    private func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(strings.language == .chinese ? "EEE" : "EEE")
        return formatter.string(from: date)
    }

    private func shortDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(strings.language == .chinese ? "M月d日" : "MMM d")
        return formatter.string(from: date)
    }
}

private struct SessionDayChip: View {
    let weekdayLabel: String
    let dateLabel: String
    let isSelected: Bool
    let selectDay: () -> Void

    var body: some View {
        Button(action: selectDay) {
            VStack(spacing: 2) {
                Text(weekdayLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(dateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.primary : .secondary)
                    .monospacedDigit()
            }
            .frame(minWidth: 64)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private enum TrendAxisLabelStyle {
    case weekday
    case dayOfMonthCompressed
    case monthDayCompressed
}

private enum InsightsExportController {
    @MainActor
    static func save(payload: HistoryExportPayload) throws -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = payload.suggestedFileName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [contentType(for: payload.format)]

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        try payload.data.write(to: url, options: .atomic)
        return true
    }

    private static func contentType(for format: HistoryExportFormat) -> UTType {
        switch format {
        case .csv:
            return .commaSeparatedText
        case .json:
            return .json
        }
    }
}

private struct TodayBalanceBar: View {
    let focusSeconds: Int
    let restSeconds: Int
    let strings: AppStrings

    private var totalSeconds: Int {
        focusSeconds + restSeconds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let fullWidth = geometry.size.width
                let focusFraction = totalSeconds > 0 ? CGFloat(focusSeconds) / CGFloat(totalSeconds) : 0
                let restFraction = totalSeconds > 0 ? CGFloat(restSeconds) / CGFloat(totalSeconds) : 0

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(focusSeconds > 0 ? 0.95 : 0.12))
                        .frame(width: max(0, fullWidth * focusFraction))

                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.orange.opacity(restSeconds > 0 ? 0.90 : 0.12))
                        .frame(width: max(0, fullWidth * restFraction))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(height: 18)

            HStack {
                Text(strings.actualDurationCaption(strings.compactDurationLabel(focusSeconds)))
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 8)
                Text(strings.actualDurationCaption(strings.compactDurationLabel(restSeconds)))
                    .foregroundStyle(.orange)
            }
            .font(.caption)
        }
    }
}

private struct TrendBucketsView: View {
    let buckets: [HistoryTrendBucket]
    let labelStyle: TrendAxisLabelStyle
    let strings: AppStrings
    let calendar: Calendar

    private let barSpacing: CGFloat = 6
    private let maxBarHeight: CGFloat = 126

    private var barWidth: CGFloat {
        switch labelStyle {
        case .weekday:
            return 28
        case .dayOfMonthCompressed:
            return 18
        case .monthDayCompressed:
            return 16
        }
    }

    private var maxCombinedSeconds: Int {
        max(buckets.map { $0.focusSeconds + $0.restSeconds }.max() ?? 0, 1)
    }

    private var contentWidth: CGFloat {
        CGFloat(buckets.count) * barWidth + CGFloat(max(buckets.count - 1, 0)) * barSpacing
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: contentWidth > 720) {
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { item in
                    TrendBucketBarView(
                        bucket: item.element,
                        index: item.offset,
                        bucketCount: buckets.count,
                        maxCombinedSeconds: maxCombinedSeconds,
                        label: axisLabel(for: item.element, index: item.offset, count: buckets.count),
                        tooltip: tooltip(for: item.element),
                        barWidth: barWidth,
                        maxBarHeight: maxBarHeight
                    )
                }
            }
            .frame(minWidth: contentWidth, alignment: .leading)
            .padding(.vertical, 2)
        }
    }

    private func axisLabel(for bucket: HistoryTrendBucket, index: Int, count: Int) -> String {
        if index == 0 || index == count - 1 {
            return monthDayFormatter.string(from: bucket.startDate)
        }

        switch labelStyle {
        case .weekday:
            guard index % 2 == 0 else {
                return ""
            }
            return strings.weekdayTrendLabel(calendar.component(.weekday, from: bucket.startDate))
        case .dayOfMonthCompressed:
            guard index % 5 == 0 else {
                return ""
            }
            return dayNumberFormatter.string(from: bucket.startDate)
        case .monthDayCompressed:
            guard index % 4 == 0 else {
                return ""
            }
            return monthDayFormatter.string(from: bucket.startDate)
        }
    }

    private func tooltip(for bucket: HistoryTrendBucket) -> String {
        let dateText: String
        switch bucket.unit {
        case .day:
            dateText = fullDateFormatter.string(from: bucket.startDate)
        case .week:
            let endDate = bucket.endDate.addingTimeInterval(-1)
            dateText = "\(fullDateFormatter.string(from: bucket.startDate)) - \(fullDateFormatter.string(from: endDate))"
        }

        let focusText = strings.compactDurationLabel(bucket.focusSeconds)
        let restText = strings.compactDurationLabel(bucket.restSeconds)
        let totalText = strings.compactDurationLabel(bucket.focusSeconds + bucket.restSeconds)

        return [
            dateText,
            "\(strings.todayFocusTitle): \(focusText)",
            "\(strings.todayRestTitle): \(restText)",
            "\(strings.totalTitle): \(totalText)",
        ].joined(separator: "\n")
    }

    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = strings.language == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(strings.language == .chinese ? "y年M月d日" : "MMM d, y")
        return formatter
    }

    private var dayNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = strings.language == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter
    }

    private var monthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = strings.language == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(strings.language == .chinese ? "M月d日" : "MMM d")
        return formatter
    }
}

private struct TrendBucketBarView: View {
    let bucket: HistoryTrendBucket
    let index: Int
    let bucketCount: Int
    let maxCombinedSeconds: Int
    let label: String
    let tooltip: String
    let barWidth: CGFloat
    let maxBarHeight: CGFloat

    private let segmentSpacing: CGFloat = 2
    private let innerPadding: CGFloat = 2

    private var combinedSeconds: Int {
        bucket.focusSeconds + bucket.restSeconds
    }

    private var trackHeight: CGFloat {
        maxBarHeight - innerPadding * 2
    }

    private var trackWidth: CGFloat {
        max(barWidth - innerPadding * 2, 8)
    }

    private var effectiveSegmentSpacing: CGFloat {
        bucket.focusSeconds > 0 && bucket.restSeconds > 0 ? segmentSpacing : 0
    }

    private var drawableHeight: CGFloat {
        max(0, totalHeight - effectiveSegmentSpacing)
    }

    private var totalHeight: CGFloat {
        guard combinedSeconds > 0 else {
            return 0
        }
        return max(10, CGFloat(combinedSeconds) / CGFloat(maxCombinedSeconds) * trackHeight)
    }

    private var focusHeight: CGFloat {
        guard combinedSeconds > 0 else { return 0 }
        return drawableHeight * CGFloat(bucket.focusSeconds) / CGFloat(max(combinedSeconds, 1))
    }

    private var restHeight: CGFloat {
        guard combinedSeconds > 0 else { return 0 }
        return drawableHeight * CGFloat(bucket.restSeconds) / CGFloat(max(combinedSeconds, 1))
    }

    private var labelWidth: CGFloat {
        max(barWidth + 8, label.count > 3 ? 46 : 24)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))

                VStack(spacing: effectiveSegmentSpacing) {
                    Spacer(minLength: 0)

                    if restHeight > 0 {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.orange.opacity(index == bucketCount - 1 ? 0.95 : 0.78))
                            .frame(width: trackWidth, height: restHeight)
                    }

                    if focusHeight > 0 {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(index == bucketCount - 1 ? 1.0 : 0.86))
                            .frame(width: trackWidth, height: focusHeight)
                    }
                }
                .frame(width: trackWidth, height: trackHeight)
                .padding(innerPadding)
            }
            .frame(width: barWidth, height: maxBarHeight)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help(tooltip)

            Text(label)
                .font(.caption2.weight(index == bucketCount - 1 ? .semibold : .regular))
                .foregroundStyle(index == bucketCount - 1 ? .primary : .secondary)
                .frame(width: labelWidth)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct SessionRowView: View {
    let entry: HistorySessionEntry
    let strings: AppStrings
    let dateTimeLabel: String
    let summaryLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))

                    if entry.isHiddenRest {
                        Text(strings.hiddenRestTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.orange.opacity(0.14))
                            )
                    }
                }

                Text(summaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(dateTimeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(strings.actualDurationCaption(strings.compactDurationLabel(entry.actualSeconds)))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()

                if entry.scheduledSeconds != entry.actualSeconds {
                    Text(strings.plannedDurationCaption(strings.compactDurationLabel(entry.scheduledSeconds)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var primaryTitle: String {
        switch entry.kind {
        case .focus:
            return strings.historySessionKindTitle(.focus)
        case .rest:
            if entry.isHiddenRest, let restSource = entry.restSource {
                return strings.restSourceTitle(restSource)
            }
            return strings.breakPresetTitle(entry.breakKind ?? .standard)
        }
    }
}
