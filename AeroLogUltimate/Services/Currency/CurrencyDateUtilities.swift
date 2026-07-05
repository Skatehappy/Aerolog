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
}