import Foundation

public struct DailyTrendDay: Identifiable, Sendable {
    public let startDate: Date
    public let focusSeconds: Int
    public let restSeconds: Int

    public var id: Date { startDate }

    public init(startDate: Date, focusSeconds: Int, restSeconds: Int) {
        self.startDate = startDate
        self.focusSeconds = focusSeconds
        self.restSeconds = restSeconds
    }
}

public struct DailyTotalsSnapshot: Sendable {
    public let todayStartDate: Date
    public let focusSeconds: Int
    public let restSeconds: Int
    public let trendDays: [DailyTrendDay]

    public init(todayStartDate: Date, focusSeconds: Int, restSeconds: Int, trendDays: [DailyTrendDay]) {
        self.todayStartDate = todayStartDate
        self.focusSeconds = focusSeconds
        self.restSeconds = restSeconds
        self.trendDays = trendDays
    }
}

public struct ActiveSessionSnapshot: Sendable {
    public enum Kind: Sendable {
        case focus
        case rest
    }

    public let kind: Kind
    public let startedAt: Date
    public let scheduledSeconds: Int
    public let breakKind: BreakKind?

    public init(kind: Kind, startedAt: Date, scheduledSeconds: Int, breakKind: BreakKind?) {
        self.kind = kind
        self.startedAt = startedAt
        self.scheduledSeconds = scheduledSeconds
        self.breakKind = breakKind
    }
}

public enum DailyTotalsCalculator {
    public static let minimumCountedSessionSeconds = 10

    public static func snapshot(
        focusSessions: [FocusSession],
        restSessions: [RestSession],
        activePhase: ActiveSessionSnapshot?,
        dayBoundaryHour: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> DailyTotalsSnapshot {
        let normalizedCutoff = max(0, min(23, dayBoundaryHour))
        let reportingCalendar = reportingCalendar(from: calendar)
        let todayStart = reportingDayStart(containing: now, dayBoundaryHour: normalizedCutoff, calendar: reportingCalendar)
        let dayStarts = (0..<7).compactMap { offset in
            reportingCalendar.date(byAdding: .day, value: offset - 6, to: todayStart)
        }

        let recordedFocusIntervals = focusSessions
            .filter { $0.actualFocusSeconds >= minimumCountedSessionSeconds }
            .map { SessionInterval(startedAt: $0.startedAt, endedAt: $0.endedAt, kind: .focus) }
        let recordedRestIntervals = restSessions
            .filter { $0.actualRestSeconds >= minimumCountedSessionSeconds }
            .map { SessionInterval(startedAt: $0.startedAt, endedAt: $0.endedAt, kind: .rest) }

        var intervals = recordedFocusIntervals + recordedRestIntervals
        if let activeInterval = activeInterval(from: activePhase, now: now),
           activeInterval.durationSeconds >= minimumCountedSessionSeconds {
            intervals.append(activeInterval)
        }

        let trendDays = dayStarts.map { dayStart in
            let dayEnd = reportingCalendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let focusSeconds = intervals
                .filter { $0.kind == .focus }
                .reduce(0) { $0 + overlapSeconds(of: $1, in: dayStart..<dayEnd) }
            let restSeconds = intervals
                .filter { $0.kind == .rest }
                .reduce(0) { $0 + overlapSeconds(of: $1, in: dayStart..<dayEnd) }
            return DailyTrendDay(startDate: dayStart, focusSeconds: focusSeconds, restSeconds: restSeconds)
        }

        let today = trendDays.last ?? DailyTrendDay(startDate: todayStart, focusSeconds: 0, restSeconds: 0)
        return DailyTotalsSnapshot(
            todayStartDate: todayStart,
            focusSeconds: today.focusSeconds,
            restSeconds: today.restSeconds,
            trendDays: trendDays
        )
    }

    public static func reportingDayStart(
        containing date: Date,
        dayBoundaryHour: Int,
        calendar: Calendar = .current
    ) -> Date {
        let reportingCalendar = reportingCalendar(from: calendar)
        let shiftedDate = reportingCalendar.date(byAdding: .hour, value: -max(0, min(23, dayBoundaryHour)), to: date) ?? date
        let shiftedStartOfDay = reportingCalendar.startOfDay(for: shiftedDate)
        return reportingCalendar.date(byAdding: .hour, value: max(0, min(23, dayBoundaryHour)), to: shiftedStartOfDay) ?? shiftedStartOfDay
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

    private static func reportingCalendar(from base: Calendar) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private struct SessionInterval {
        enum Kind: Equatable {
            case focus
            case rest
        }

        let startedAt: Date
        let endedAt: Date
        let kind: Kind

        var durationSeconds: Int {
            max(0, Int(endedAt.timeIntervalSince(startedAt)))
        }
    }
}
