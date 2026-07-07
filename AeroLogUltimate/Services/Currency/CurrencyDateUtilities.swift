import Foundation

/// Calendar helpers for FAA lookback windows (calendar months vs. rolling days).
enum CurrencyDateUtilities {
    static let calendar = Calendar.current

    /// Start of day for consistent date comparisons.
    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Rolling day lookback (e.g. 90 preceding days for 61.57(a)).
    static func windowStart(days: Int, from reference: Date = .now) -> Date {
        let end = startOfDay(reference)
        return calendar.date(byAdding: .day, value: -days, to: end) ?? end
    }

    /// Calendar month lookback (e.g. 6 calendar months for 61.57(c)).
    static func windowStart(months: Int, from reference: Date = .now) -> Date {
        let end = startOfDay(reference)
        return calendar.date(byAdding: .month, value: -months, to: end) ?? end
    }

    /// H1: FAA calendar-month rules (61.56, 61.57(c), 61.57(d)) stay valid through
    /// the LAST day of the Nth calendar month after the event — not the exact day.
    /// e.g. a flight review completed Jul 5 2024 is valid through Jul 31 2026.
    static func endOfCalendarMonth(afterAdding months: Int, to date: Date) -> Date {
        let base = startOfDay(date)
        guard let shifted = calendar.date(byAdding: .month, value: months, to: base) else { return base }
        let monthComps = calendar.dateComponents([.year, .month], from: shifted)
        guard let firstOfMonth = calendar.date(from: monthComps),
              let firstOfNextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth),
              let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: firstOfNextMonth) else {
            return shifted
        }
        return startOfDay(lastOfMonth)
    }

    /// H1: start of an "N calendar months preceding" window (61.57(c)/(d)) — the
    /// FIRST day of the calendar month N months before the reference month, so
    /// approaches flown early in that month aren't wrongly excluded.
    static func startOfCalendarMonthWindow(months: Int, from reference: Date = .now) -> Date {
        let base = startOfDay(reference)
        guard let shifted = calendar.date(byAdding: .month, value: -months, to: base) else { return base }
        let monthComps = calendar.dateComponents([.year, .month], from: shifted)
        return calendar.date(from: monthComps) ?? shifted
    }

    /// Days from today until a date (negative if past).
    static func daysUntil(_ date: Date, from reference: Date = .now) -> Int {
        let start = startOfDay(reference)
        let end = startOfDay(date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Expiration date from the oldest contributing event in a rolling window.
    static func rollingExpiration(
        eventDates: [Date],
        requiredCount: Int,
        windowDays: Int
    ) -> Date? {
        guard requiredCount > 0, !eventDates.isEmpty else { return nil }
        let sorted = eventDates.sorted(by: >)
        guard sorted.count >= requiredCount else {
            if let oldest = sorted.last {
                return calendar.date(byAdding: .day, value: windowDays, to: startOfDay(oldest))
            }
            return nil
        }
        let anchor = sorted[requiredCount - 1]
        return calendar.date(byAdding: .day, value: windowDays, to: startOfDay(anchor))
    }

    /// Expiration for calendar-month rolling windows (e.g. 61.57(c) instrument approaches).
    static func rollingExpirationMonths(
        eventDates: [Date],
        requiredCount: Int,
        windowMonths: Int
    ) -> Date? {
        guard requiredCount > 0, !eventDates.isEmpty else { return nil }
        let sorted = eventDates.sorted(by: >)
        // H1: currency lapses at the END of the anchor's Nth calendar month.
        guard sorted.count >= requiredCount else {
            if let oldest = sorted.last {
                return endOfCalendarMonth(afterAdding: windowMonths, to: oldest)
            }
            return nil
        }
        let anchor = sorted[requiredCount - 1]
        return endOfCalendarMonth(afterAdding: windowMonths, to: anchor)
    }
}