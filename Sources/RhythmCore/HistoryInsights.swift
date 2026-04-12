import Foundation

public enum HistoryDisplayRange: String, Codable, CaseIterable, Sendable {
    case today
    case last7Days
    case last30Days
    case allTime
}

public enum HistoryTrendUnit: String, Codable, Sendable {
    case day
    case week
}

public struct HistoryTrendBucket: Identifiable, Codable, Sendable {
    public let unit: HistoryTrendUnit
    public let startDate: Date
    public let endDate: Date
    public let focusSeconds: Int
    public let restSeconds: Int

    public var id: String {
        "\(unit.rawValue)-\(startDate.timeIntervalSince1970)"
    }

    public init(
        unit: HistoryTrendUnit,
        startDate: Date,
        endDate: Date,
        focusSeconds: Int,
        restSeconds: Int
    ) {
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.focusSeconds = focusSeconds
        self.restSeconds = restSeconds
    }
}

public struct HistoryRangeSnapshot: Codable, Sendable {
    public let kind: HistoryDisplayRange
    public let startDate: Date
    public let endDate: Date
    public let focusSeconds: Int
    public let restSeconds: Int
    public let trendBuckets: [HistoryTrendBucket]

    public init(
        kind: HistoryDisplayRange,
        startDate: Date,
        endDate: Date,
        focusSeconds: Int,
        restSeconds: Int,
        trendBuckets: [HistoryTrendBucket]
    ) {
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.focusSeconds = focusSeconds
        self.restSeconds = restSeconds
        self.trendBuckets = trendBuckets
    }
}

public enum HistorySessionKind: String, Codable, Sendable {
    case focus
    case rest
}

public struct HistorySessionEntry: Identifiable, Codable, Sendable {
    public let sessionID: UUID
    public let reportingDayStart: Date
    public let startedAt: Date
    public let endedAt: Date
    public let kind: HistorySessionKind
    public let scheduledSeconds: Int
    public let actualSeconds: Int
    public let breakKind: BreakKind?
    public let restSource: RestSessionSource?
    public let skipped: Bool
    public let skipReason: String?
    public let focusEndReason: FocusEndReason?
    public let createdAt: Date

    public var id: String {
        "\(kind.rawValue)-\(sessionID.uuidString)"
    }

    public var isHiddenRest: Bool {
        kind == .rest && restSource != .timer
    }

    public init(
        sessionID: UUID,
        reportingDayStart: Date,
        startedAt: Date,
        endedAt: Date,
        kind: HistorySessionKind,
        scheduledSeconds: Int,
        actualSeconds: Int,
        breakKind: BreakKind?,
        restSource: RestSessionSource?,
        skipped: Bool,
        skipReason: String?,
        focusEndReason: FocusEndReason?,
        createdAt: Date
    ) {
        self.sessionID = sessionID
        self.reportingDayStart = reportingDayStart
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.kind = kind
        self.scheduledSeconds = scheduledSeconds
        self.actualSeconds = actualSeconds
        self.breakKind = breakKind
        self.restSource = restSource
        self.skipped = skipped
        self.skipReason = skipReason
        self.focusEndReason = focusEndReason
        self.createdAt = createdAt
    }
}

public struct HistoryInsightsSnapshot: Codable, Sendable {
    public let generatedAt: Date
    public let dayBoundaryHour: Int
    public let today: HistoryRangeSnapshot
    public let last7Days: HistoryRangeSnapshot
    public let last30Days: HistoryRangeSnapshot
    public let allTime: HistoryRangeSnapshot
    public let sessionEntries: [HistorySessionEntry]

    public init(
        generatedAt: Date,
        dayBoundaryHour: Int,
        today: HistoryRangeSnapshot,
        last7Days: HistoryRangeSnapshot,
        last30Days: HistoryRangeSnapshot,
        allTime: HistoryRangeSnapshot,
        sessionEntries: [HistorySessionEntry]
    ) {
        self.generatedAt = generatedAt
        self.dayBoundaryHour = dayBoundaryHour
        self.today = today
        self.last7Days = last7Days
        self.last30Days = last30Days
        self.allTime = allTime
        self.sessionEntries = sessionEntries
    }
}

public enum HistoryExportFormat: String, Sendable {
    case csv
    case json

    public var fileExtension: String {
        switch self {
        case .csv:
            return "csv"
        case .json:
            return "json"
        }
    }
}

public enum HistoryExportScope: Equatable, Sendable, Codable {
    case today
    case last7Days
    case last30Days
    case allTime
    case reportingDay(startDate: Date)

    private enum CodingKeys: String, CodingKey {
        case kind
        case reportingDayStart
    }

    private enum Kind: String, Codable {
        case today
        case last7Days
        case last30Days
        case allTime
        case reportingDay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .today:
            self = .today
        case .last7Days:
            self = .last7Days
        case .last30Days:
            self = .last30Days
        case .allTime:
            self = .allTime
        case .reportingDay:
            self = .reportingDay(
                startDate: try container.decode(Date.self, forKey: .reportingDayStart)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .today:
            try container.encode(Kind.today, forKey: .kind)
        case .last7Days:
            try container.encode(Kind.last7Days, forKey: .kind)
        case .last30Days:
            try container.encode(Kind.last30Days, forKey: .kind)
        case .allTime:
            try container.encode(Kind.allTime, forKey: .kind)
        case let .reportingDay(startDate):
            try container.encode(Kind.reportingDay, forKey: .kind)
            try container.encode(startDate, forKey: .reportingDayStart)
        }
    }
}

public struct HistoryExportPayload: Sendable {
    public let format: HistoryExportFormat
    public let suggestedFileName: String
    public let data: Data

    public init(format: HistoryExportFormat, suggestedFileName: String, data: Data) {
        self.format = format
        self.suggestedFileName = suggestedFileName
        self.data = data
    }
}

public struct HistoryExportPreview: Sendable {
    public let scope: HistoryExportScope
    public let sessionCount: Int
    public let rangeStart: Date
    public let rangeEnd: Date

    public init(scope: HistoryExportScope, sessionCount: Int, rangeStart: Date, rangeEnd: Date) {
        self.scope = scope
        self.sessionCount = sessionCount
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }
}

private struct HistoryExportEnvelope: Codable, Sendable {
    let exportedAt: Date
    let scope: HistoryExportScope
    let dayBoundaryHour: Int
    let rangeStart: Date
    let rangeEnd: Date
    let sessions: [HistorySessionEntry]
}

private struct ResolvedHistoryExport: Sendable {
    let scope: HistoryExportScope
    let dayBoundaryHour: Int
    let rangeStart: Date
    let rangeEnd: Date
    let anchorDate: Date
    let sessions: [HistorySessionEntry]
}

public enum HistoryInsightsCalculator {
    public static func snapshot(
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        activePhase: ActiveSessionSnapshot?,
        dayBoundaryHour: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> HistoryInsightsSnapshot {
        let normalizedCutoff = normalizedDayBoundaryHour(dayBoundaryHour)
        let reportingCalendar = reportingCalendar(from: calendar)
        let todayStart = reportingDayStart(
            containing: now,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )
        let nextDayStart = nextReportingDayStart(after: todayStart, calendar: reportingCalendar)
        let intervals = countedIntervals(
            focusSessions: focusSessions,
            restSessions: restSessions,
            activePhase: activePhase,
            now: now
        )
        let sessionEntries = makeSessionEntries(
            focusSessions: focusSessions,
            restSessions: restSessions,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )

        let today = makeDailyRangeSnapshot(
            kind: .today,
            startDate: todayStart,
            dayCount: 1,
            intervals: intervals,
            calendar: reportingCalendar
        )
        let last7Days = makeDailyRangeSnapshot(
            kind: .last7Days,
            startDate: reportingCalendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart,
            dayCount: 7,
            intervals: intervals,
            calendar: reportingCalendar
        )
        let last30Days = makeDailyRangeSnapshot(
            kind: .last30Days,
            startDate: reportingCalendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart,
            dayCount: 30,
            intervals: intervals,
            calendar: reportingCalendar
        )

        let allTimeStart = earliestReportingDayStart(
            focusSessions: focusSessions,
            restSessions: restSessions,
            activePhase: activePhase,
            fallback: todayStart,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )
        let allTimeDailyBuckets = makeDailyBuckets(
            startDate: allTimeStart,
            dayCount: dayCount(from: allTimeStart, to: todayStart, calendar: reportingCalendar),
            intervals: intervals,
            calendar: reportingCalendar
        )
        let allTimeTrendBuckets = aggregateWeeklyBuckets(
            from: allTimeDailyBuckets,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )
        let allTimeTotals = totals(for: allTimeDailyBuckets)
        let allTime = HistoryRangeSnapshot(
            kind: .allTime,
            startDate: allTimeStart,
            endDate: nextDayStart,
            focusSeconds: allTimeTotals.focusSeconds,
            restSeconds: allTimeTotals.restSeconds,
            trendBuckets: allTimeTrendBuckets
        )

        return HistoryInsightsSnapshot(
            generatedAt: now,
            dayBoundaryHour: normalizedCutoff,
            today: today,
            last7Days: last7Days,
            last30Days: last30Days,
            allTime: allTime,
            sessionEntries: sessionEntries
        )
    }

    public static func exportPreview(
        scope: HistoryExportScope,
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        dayBoundaryHour: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> HistoryExportPreview {
        let resolved = resolveExport(
            scope: scope,
            focusSessions: focusSessions,
            restSessions: restSessions,
            dayBoundaryHour: dayBoundaryHour,
            now: now,
            calendar: calendar
        )

        return HistoryExportPreview(
            scope: resolved.scope,
            sessionCount: resolved.sessions.count,
            rangeStart: resolved.rangeStart,
            rangeEnd: resolved.rangeEnd
        )
    }

    public static func export(
        scope: HistoryDisplayRange,
        format: HistoryExportFormat,
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        dayBoundaryHour: Int,
        now: Date,
        calendar: Calendar = .current
    ) throws -> HistoryExportPayload {
        try export(
            scope: HistoryExportScope.from(scope),
            format: format,
            focusSessions: focusSessions,
            restSessions: restSessions,
            dayBoundaryHour: dayBoundaryHour,
            now: now,
            calendar: calendar
        )
    }

    public static func export(
        scope: HistoryExportScope,
        format: HistoryExportFormat,
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        dayBoundaryHour: Int,
        now: Date,
        calendar: Calendar = .current
    ) throws -> HistoryExportPayload {
        let resolved = resolveExport(
            scope: scope,
            focusSessions: focusSessions,
            restSessions: restSessions,
            dayBoundaryHour: dayBoundaryHour,
            now: now,
            calendar: calendar
        )
        let reportingCalendar = reportingCalendar(from: calendar)
        let suggestedFileName = suggestedFileName(
            scope: resolved.scope,
            format: format,
            anchorDate: resolved.anchorDate,
            calendar: reportingCalendar
        )

        switch format {
        case .csv:
            let data = makeCSVData(from: resolved.sessions)
            return HistoryExportPayload(format: format, suggestedFileName: suggestedFileName, data: data)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(HistoryExportEnvelope(
                exportedAt: now,
                scope: resolved.scope,
                dayBoundaryHour: resolved.dayBoundaryHour,
                rangeStart: resolved.rangeStart,
                rangeEnd: resolved.rangeEnd,
                sessions: resolved.sessions
            ))
            return HistoryExportPayload(format: format, suggestedFileName: suggestedFileName, data: data)
        }
    }

    private static func resolveExport(
        scope: HistoryExportScope,
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        dayBoundaryHour: Int,
        now: Date,
        calendar: Calendar
    ) -> ResolvedHistoryExport {
        let normalizedCutoff = normalizedDayBoundaryHour(dayBoundaryHour)
        let reportingCalendar = reportingCalendar(from: calendar)
        let todayStart = reportingDayStart(
            containing: now,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )
        let nextDayStart = nextReportingDayStart(after: todayStart, calendar: reportingCalendar)
        let allEntries = makeSessionEntries(
            focusSessions: focusSessions,
            restSessions: restSessions,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )
        let earliestStart = earliestReportingDayStart(
            focusSessions: focusSessions,
            restSessions: restSessions,
            activePhase: nil,
            fallback: todayStart,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )
        let exportRange = exportRange(
            for: scope,
            todayStart: todayStart,
            nextDayStart: nextDayStart,
            earliestStart: earliestStart,
            dayBoundaryHour: normalizedCutoff,
            calendar: reportingCalendar
        )
        let scopedEntries = allEntries
            .filter { overlaps(startedAt: $0.startedAt, endedAt: $0.endedAt, range: exportRange) }
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.startedAt < rhs.startedAt
            }

        return ResolvedHistoryExport(
            scope: scope,
            dayBoundaryHour: normalizedCutoff,
            rangeStart: exportRange.lowerBound,
            rangeEnd: exportRange.upperBound,
            anchorDate: anchorDate(
                for: scope,
                todayStart: todayStart,
                dayBoundaryHour: normalizedCutoff,
                calendar: reportingCalendar
            ),
            sessions: scopedEntries
        )
    }

    private static func makeDailyRangeSnapshot(
        kind: HistoryDisplayRange,
        startDate: Date,
        dayCount: Int,
        intervals: [SessionInterval],
        calendar: Calendar
    ) -> HistoryRangeSnapshot {
        let buckets = makeDailyBuckets(
            startDate: startDate,
            dayCount: dayCount,
            intervals: intervals,
            calendar: calendar
        )
        let totals = totals(for: buckets)
        let endDate = nextReportingDayStart(
            after: calendar.date(byAdding: .day, value: dayCount - 1, to: startDate) ?? startDate,
            calendar: calendar
        )

        return HistoryRangeSnapshot(
            kind: kind,
            startDate: startDate,
            endDate: endDate,
            focusSeconds: totals.focusSeconds,
            restSeconds: totals.restSeconds,
            trendBuckets: buckets
        )
    }

    private static func makeDailyBuckets(
        startDate: Date,
        dayCount: Int,
        intervals: [SessionInterval],
        calendar: Calendar
    ) -> [HistoryTrendBucket] {
        guard dayCount > 0 else {
            return []
        }

        return (0..<dayCount).map { offset in
            let bucketStart = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let bucketEnd = nextReportingDayStart(after: bucketStart, calendar: calendar)
            let focusSeconds = intervals
                .filter { $0.kind == .focus }
                .reduce(0) { $0 + overlapSeconds(of: $1, in: bucketStart..<bucketEnd) }
            let restSeconds = intervals
                .filter { $0.kind == .rest }
                .reduce(0) { $0 + overlapSeconds(of: $1, in: bucketStart..<bucketEnd) }

            return HistoryTrendBucket(
                unit: .day,
                startDate: bucketStart,
                endDate: bucketEnd,
                focusSeconds: focusSeconds,
                restSeconds: restSeconds
            )
        }
    }

    private static func aggregateWeeklyBuckets(
        from dailyBuckets: [HistoryTrendBucket],
        dayBoundaryHour: Int,
        calendar: Calendar
    ) -> [HistoryTrendBucket] {
        let grouped = Dictionary(grouping: dailyBuckets) {
            reportingWeekStart(
                containing: $0.startDate,
                dayBoundaryHour: dayBoundaryHour,
                calendar: calendar
            )
        }

        return grouped.keys.sorted().map { weekStart in
            let buckets = grouped[weekStart] ?? []
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return HistoryTrendBucket(
                unit: .week,
                startDate: weekStart,
                endDate: weekEnd,
                focusSeconds: buckets.reduce(0) { $0 + $1.focusSeconds },
                restSeconds: buckets.reduce(0) { $0 + $1.restSeconds }
            )
        }
    }

    private static func countedIntervals(
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        activePhase: ActiveSessionSnapshot?,
        now: Date
    ) -> [SessionInterval] {
        let recordedFocusIntervals = focusSessions
            .filter { $0.actualFocusSeconds >= DailyTotalsCalculator.minimumCountedSessionSeconds }
            .map { SessionInterval(startedAt: $0.startedAt, endedAt: $0.endedAt, kind: .focus) }
        let recordedRestIntervals = restSessions
            .filter { $0.actualRestSeconds >= DailyTotalsCalculator.minimumCountedSessionSeconds }
            .map { SessionInterval(startedAt: $0.startedAt, endedAt: $0.endedAt, kind: .rest) }

        var intervals = recordedFocusIntervals + recordedRestIntervals
        if let activeInterval = activeInterval(from: activePhase, now: now),
           activeInterval.durationSeconds >= DailyTotalsCalculator.minimumCountedSessionSeconds {
            intervals.append(activeInterval)
        }

        return intervals
    }

    private static func makeSessionEntries(
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        dayBoundaryHour: Int,
        calendar: Calendar
    ) -> [HistorySessionEntry] {
        let focusEntries = focusSessions.map { session in
            HistorySessionEntry(
                sessionID: session.id,
                reportingDayStart: reportingDayStart(
                    containing: session.startedAt,
                    dayBoundaryHour: dayBoundaryHour,
                    calendar: calendar
                ),
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                kind: .focus,
                scheduledSeconds: session.scheduledFocusSeconds,
                actualSeconds: session.actualFocusSeconds,
                breakKind: nil,
                restSource: nil,
                skipped: false,
                skipReason: nil,
                focusEndReason: session.endReason,
                createdAt: session.createdAt
            )
        }
        let restEntries = restSessions.map { session in
            HistorySessionEntry(
                sessionID: session.id,
                reportingDayStart: reportingDayStart(
                    containing: session.startedAt,
                    dayBoundaryHour: dayBoundaryHour,
                    calendar: calendar
                ),
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                kind: .rest,
                scheduledSeconds: session.scheduledRestSeconds,
                actualSeconds: session.actualRestSeconds,
                breakKind: session.breakKind,
                restSource: session.source,
                skipped: session.skipped,
                skipReason: session.skipReason,
                focusEndReason: nil,
                createdAt: session.createdAt
            )
        }

        return (focusEntries + restEntries).sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.startedAt > rhs.startedAt
        }
    }

    private static func totals(for buckets: [HistoryTrendBucket]) -> (focusSeconds: Int, restSeconds: Int) {
        (
            focusSeconds: buckets.reduce(0) { $0 + $1.focusSeconds },
            restSeconds: buckets.reduce(0) { $0 + $1.restSeconds }
        )
    }

    private static func exportRange(
        for scope: HistoryExportScope,
        todayStart: Date,
        nextDayStart: Date,
        earliestStart: Date,
        dayBoundaryHour: Int,
        calendar: Calendar
    ) -> Range<Date> {
        let startDate: Date
        let endDate: Date
        switch scope {
        case .today:
            startDate = todayStart
            endDate = nextDayStart
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            endDate = nextDayStart
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
            endDate = nextDayStart
        case .allTime:
            startDate = earliestStart
            endDate = nextDayStart
        case let .reportingDay(startDateValue):
            startDate = reportingDayStart(
                containing: startDateValue,
                dayBoundaryHour: dayBoundaryHour,
                calendar: calendar
            )
            endDate = nextReportingDayStart(after: startDate, calendar: calendar)
        }

        return startDate..<endDate
    }

    private static func earliestReportingDayStart(
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        activePhase: ActiveSessionSnapshot?,
        fallback: Date,
        dayBoundaryHour: Int,
        calendar: Calendar
    ) -> Date {
        let earliestDate = (
            focusSessions.map(\.startedAt) +
            restSessions.map(\.startedAt) +
            [activePhase?.startedAt].compactMap { $0 }
        ).min()

        return reportingDayStart(
            containing: earliestDate ?? fallback,
            dayBoundaryHour: dayBoundaryHour,
            calendar: calendar
        )
    }

    private static func dayCount(from startDate: Date, to endDate: Date, calendar: Calendar) -> Int {
        let distance = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(distance + 1, 1)
    }

    private static func overlaps(
        startedAt: Date,
        endedAt: Date,
        range: Range<Date>
    ) -> Bool {
        startedAt < range.upperBound && endedAt > range.lowerBound
    }

    private static func makeCSVData(from sessions: [HistorySessionEntry]) -> Data {
        let header = [
            "kind",
            "session_id",
            "reporting_day_start",
            "started_at",
            "ended_at",
            "scheduled_seconds",
            "actual_seconds",
            "break_kind",
            "rest_source",
            "focus_end_reason",
            "skipped",
            "skip_reason",
            "created_at"
        ].joined(separator: ",")

        let formatter = iso8601Formatter()
        let rows = sessions.map { session in
            [
                session.kind.rawValue,
                session.sessionID.uuidString,
                formatter.string(from: session.reportingDayStart),
                formatter.string(from: session.startedAt),
                formatter.string(from: session.endedAt),
                String(session.scheduledSeconds),
                String(session.actualSeconds),
                session.breakKind?.rawValue ?? "",
                session.restSource?.rawValue ?? "",
                session.focusEndReason?.rawValue ?? "",
                String(session.skipped),
                session.skipReason ?? "",
                formatter.string(from: session.createdAt)
            ]
            .map(csvField)
            .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private static func suggestedFileName(
        scope: HistoryExportScope,
        format: HistoryExportFormat,
        anchorDate: Date,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStamp = formatter.string(from: anchorDate)
        return "rhythm-\(scope.fileNameComponent)-\(dateStamp).\(format.fileExtension)"
    }

    private static func anchorDate(
        for scope: HistoryExportScope,
        todayStart: Date,
        dayBoundaryHour: Int,
        calendar: Calendar
    ) -> Date {
        switch scope {
        case .today, .last7Days, .last30Days, .allTime:
            return todayStart
        case let .reportingDay(startDate):
            return reportingDayStart(
                containing: startDate,
                dayBoundaryHour: dayBoundaryHour,
                calendar: calendar
            )
        }
    }

    private static func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func iso8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func normalizedDayBoundaryHour(_ hour: Int) -> Int {
        max(0, min(23, hour))
    }

    private static func reportingCalendar(from base: Calendar) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private static func reportingDayStart(
        containing date: Date,
        dayBoundaryHour: Int,
        calendar: Calendar
    ) -> Date {
        DailyTotalsCalculator.reportingDayStart(
            containing: date,
            dayBoundaryHour: dayBoundaryHour,
            calendar: calendar
        )
    }

    private static func nextReportingDayStart(after dayStart: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    }

    private static func reportingWeekStart(
        containing date: Date,
        dayBoundaryHour: Int,
        calendar: Calendar
    ) -> Date {
        let shiftedDate = calendar.date(byAdding: .hour, value: -dayBoundaryHour, to: date) ?? date
        let shiftedWeekStart = calendar.dateInterval(of: .weekOfYear, for: shiftedDate)?.start
            ?? calendar.startOfDay(for: shiftedDate)
        return calendar.date(byAdding: .hour, value: dayBoundaryHour, to: shiftedWeekStart) ?? shiftedWeekStart
    }

    private static func overlapSeconds(of interval: SessionInterval, in range: Range<Date>) -> Int {
        let overlapStart = max(interval.startedAt, range.lowerBound)
        let overlapEnd = min(interval.endedAt, range.upperBound)
        return max(0, Int(overlapEnd.timeIntervalSince(overlapStart)))
    }

    private static func activeInterval(from snapshot: ActiveSessionSnapshot?, now: Date) -> SessionInterval? {
        guard let snapshot, now > snapshot.startedAt else {
            return nil
        }

        switch snapshot.kind {
        case .focus:
            return SessionInterval(startedAt: snapshot.startedAt, endedAt: now, kind: .focus)
        case .rest:
            return SessionInterval(startedAt: snapshot.startedAt, endedAt: now, kind: .rest)
        }
    }

    private struct SessionInterval {
        let startedAt: Date
        let endedAt: Date
        let kind: HistorySessionKind

        var durationSeconds: Int {
            max(0, Int(endedAt.timeIntervalSince(startedAt)))
        }
    }
}

private extension HistoryExportScope {
    static func from(_ range: HistoryDisplayRange) -> Self {
        switch range {
        case .today:
            return .today
        case .last7Days:
            return .last7Days
        case .last30Days:
            return .last30Days
        case .allTime:
            return .allTime
        }
    }

    var fileNameComponent: String {
        switch self {
        case .today:
            return "today"
        case .last7Days:
            return "last7Days"
        case .last30Days:
            return "last30Days"
        case .allTime:
            return "allTime"
        case .reportingDay:
            return "selectedDay"
        }
    }
}
