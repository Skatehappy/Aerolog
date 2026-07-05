import Foundation

/// Decimal-hour conversions for logbook time entry (e.g. 1.5 = 1h 30m).
enum TimeFormatting {
    /// Formats decimal hours for display (e.g. 1.5 → "1.5" or "1:30").
    static func display(_ hours: Double, style: DisplayStyle = .decimal) -> String {
        switch style {
        case .decimal:
            if hours == 0 { return "0.0" }
            return String(format: "%.1f", hours)
        case .hoursMinutes:
            let totalMinutes = Int((hours * 60).rounded())
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            return String(format: "%d:%02d", h, m)
        }
    }

    /// Parses pilot-entered time strings: "1.5", "1:30", "90" (minutes if < 10 without colon).
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
            guard parts.count == 2,
                  let hours = Int(parts[0]),
                  let minutes = Int(parts[1]) else { return nil }
            return Double(hours) + Double(minutes) / 60.0
        }

        if let decimal = Double(trimmed) {
            return decimal
        }
        return nil
    }

    enum DisplayStyle {
        case decimal
        case hoursMinutes
    }
}