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

private struct InsightsSessionGroup: Identifiable {
    let dayStart: Date
    let entries: [HistorySessionEntry]

    var id: Date { dayStart }
}

struct InsightsView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore

    @State private var sessionFilter: InsightsSessionFilter = .all
    @State private var showHiddenRest = false
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

    private var filteredSessionEntries: [HistorySessionEntry] {
        snapshot.sessionEntries.filter { entry in
            guard showHiddenRest || !entry.isHiddenRest else {
                return false
            }

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

    private var sessionGroups: [InsightsSessionGroup] {
        let grouped = Dictionary(grouping: filteredSessionEntries, by: \.reportingDayStart)
        return grouped.keys
            .sorted(by: >)
            .map { dayStart in
                InsightsSessionGroup(dayStart: dayStart, entries: grouped[dayStart] ?? [])
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerSection
                todaySection
                trendSection(
                    title: strings.last7DaysTitle,
                    snapshot: snapshot.last7Days,
                    labelStyle: .weekday,
                    barWidth: 28
                )
                trendSection(
                    title: strings.last30DaysTitle,
                    snapshot: snapshot.last30Days,
                    labelStyle: .dayOfMonthCompressed,
                    barWidth: 18
                )
                trendSection(
                    title: strings.allTimeTitle,
                    snapshot: snapshot.allTime,
                    labelStyle: .monthDayCompressed,
                    barWidth: 16
                )
                sessionsSection
                exportSection
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(strings.insightsTitle)
                .font(.title2.weight(.semibold))

            Spacer(minLength: 0)

            Text(strings.dayCutoffValue(settingsStore.dayBoundaryHour))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var todaySection: some View {
        let today = snapshot.today

        return sectionContainer {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading(strings.todayTitle)
                Spacer(minLength: 0)
                Text(strings.dayCutoffValue(settingsStore.dayBoundaryHour))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                summaryMetric(
                    title: strings.todayFocusTitle,
                    value: strings.compactDurationLabel(today.focusSeconds),
                    tint: .accentColor
                )

                summaryMetric(
                    title: strings.todayRestTitle,
                    value: strings.compactDurationLabel(today.restSeconds),
                    tint: .orange
                )
            }

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
        labelStyle: TrendAxisLabelStyle,
        barWidth: CGFloat
    ) -> some View {
        sectionContainer {
            HStack(alignment: .firstTextBaseline) {
                sectionHeading(title)
                Spacer(minLength: 0)
                Text(strings.totalDurationCaption(strings.compactDurationLabel(snapshot.focusSeconds + snapshot.restSeconds)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                summaryMetric(
                    title: strings.todayFocusTitle,
                    value: strings.compactDurationLabel(snapshot.focusSeconds),
                    tint: .accentColor
                )

                summaryMetric(
                    title: strings.todayRestTitle,
                    value: strings.compactDurationLabel(snapshot.restSeconds),
                    tint: .orange
                )
            }

            TrendBucketsView(
                buckets: snapshot.trendBuckets,
                labelStyle: labelStyle,
                strings: strings,
                calendar: calendar,
                barWidth: barWidth
            )
        }
    }

    private var sessionsSection: some View {
        sectionContainer {
            HStack(alignment: .center, spacing: 12) {
                sectionHeading(strings.historySessionsTitle)

                Spacer(minLength: 0)

                Picker("", selection: $sessionFilter) {
                    Text(strings.filterAllTitle).tag(InsightsSessionFilter.all)
                    Text(strings.filterFocusTitle).tag(InsightsSessionFilter.focus)
                    Text(strings.filterRestTitle).tag(InsightsSessionFilter.rest)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 190)

                Toggle(strings.showHiddenRestTitle, isOn: $showHiddenRest)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
            }

            if sessionGroups.isEmpty {
                Text(strings.noHistoryYet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(sessionGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dayHeaderLabel(for: group.dayStart))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 0) {
                                ForEach(Array(group.entries.enumerated()), id: \.element.id) { item in
                                    SessionRowView(
                                        entry: item.element,
                                        strings: strings,
                                        dateTimeLabel: timeRangeLabel(for: item.element),
                                        summaryLabel: sessionSummaryLabel(for: item.element)
                                    )

                                    if item.offset < group.entries.count - 1 {
                                        Divider()
                                            .padding(.vertical, 8)
                                    }
                                }
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
            Button(strings.exportScopeTitle(.today)) {
                export(scope: .today, format: format)
            }
            Button(strings.exportScopeTitle(.last7Days)) {
                export(scope: .last7Days, format: format)
            }
            Button(strings.exportScopeTitle(.last30Days)) {
                export(scope: .last30Days, format: format)
            }
            Button(strings.exportScopeTitle(.allTime)) {
                export(scope: .allTime, format: format)
            }
        }
    }

    private func export(scope: HistoryDisplayRange, format: HistoryExportFormat) {
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
    private func summaryMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.10))
        )
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
    let barWidth: CGFloat

    private let barSpacing: CGFloat = 6
    private let maxBarHeight: CGFloat = 126

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
                        maxBarHeight: maxBarHeight,
                        strings: strings,
                        calendar: calendar
                    )
                }
            }
            .frame(minWidth: contentWidth, alignment: .leading)
            .padding(.vertical, 2)
        }
    }

    private func axisLabel(for bucket: HistoryTrendBucket, index: Int, count: Int) -> String {
        switch labelStyle {
        case .weekday:
            return strings.weekdayTrendLabel(calendar.component(.weekday, from: bucket.startDate))
        case .dayOfMonthCompressed:
            guard index == count - 1 || index == 0 || index % 5 == 0 else {
                return ""
            }
            return dayNumberFormatter.string(from: bucket.startDate)
        case .monthDayCompressed:
            guard index == count - 1 || index == 0 || index % 4 == 0 else {
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
            "\(strings.totalTitle): \(totalText)"
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
    let strings: AppStrings
    let calendar: Calendar

    private var combinedSeconds: Int {
        bucket.focusSeconds + bucket.restSeconds
    }

    private var totalHeight: CGFloat {
        guard combinedSeconds > 0 else {
            return 0
        }
        return max(10, CGFloat(combinedSeconds) / CGFloat(maxCombinedSeconds) * maxBarHeight)
    }

    private var focusHeight: CGFloat {
        guard combinedSeconds > 0 else { return 0 }
        return totalHeight * CGFloat(bucket.focusSeconds) / CGFloat(max(combinedSeconds, 1))
    }

    private var restHeight: CGFloat {
        guard combinedSeconds > 0 else { return 0 }
        return totalHeight * CGFloat(bucket.restSeconds) / CGFloat(max(combinedSeconds, 1))
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: barWidth, height: maxBarHeight)

                VStack(spacing: 2) {
                    if restHeight > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.orange.opacity(index == bucketCount - 1 ? 0.95 : 0.75))
                            .frame(width: barWidth, height: restHeight)
                    }

                    if focusHeight > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(index == bucketCount - 1 ? 1.0 : 0.82))
                            .frame(width: barWidth, height: focusHeight)
                    }
                }
                .frame(width: barWidth, height: maxBarHeight, alignment: .bottom)
            }
            .help(tooltip)

            Text(label)
                .font(.caption2.weight(index == bucketCount - 1 ? .semibold : .regular))
                .foregroundStyle(index == bucketCount - 1 ? .primary : .secondary)
                .frame(width: max(barWidth + 6, 24))
                .lineLimit(1)
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
