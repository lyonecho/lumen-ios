import DeviceActivity
import SwiftUI

// Shared between the app and the DeviceActivityReport extension so both refer to
// the same report by the same name. The App Group both targets share.
extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}

enum LumenScreenTime {
    static let appGroup = "group.com.lyonecho.lumen"
    static let hoursKey = "screen_hours_today"
    static let updatedKey = "screen_updated_at"
    static let selectionKey = "focus_selection"
    /// The calendar day (yyyy-MM-dd) the floor in hoursKey belongs to. The app
    /// trusts the floor only when this equals today — so a missed midnight reset
    /// never shows yesterday's number.
    static let dayKey = "screen_day"

    /// Local calendar day string, shared by the app and the monitor extension.
    static func dayStamp(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar.current
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Background monitoring (shared between app + monitor extension)

extension DeviceActivityName {
    /// The single all-day repeating activity Lumen schedules.
    static let lumenDaily = Self("Lumen Daily")
}

/// Cumulative-minute thresholds. The app registers one DeviceActivityEvent per
/// step (encoding the minutes into the event name); the monitor decodes the
/// minutes back out in eventDidReachThreshold. Keep the count modest — each is a
/// registered event and the monitor runs under a tight memory budget.
enum LumenThresholds {
    // Kept to 8 steps: the per-activity event ceiling is undocumented, so we stay
    // well clear of it while still giving useful granularity.
    static let minutes: [Int] = [15, 30, 45, 60, 90, 120, 180, 300]
    private static let prefix = "min_"

    /// e.g. 30 -> DeviceActivityEvent.Name("min_30")
    static func name(forMinutes m: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("\(prefix)\(m)")
    }

    /// e.g. DeviceActivityEvent.Name("min_30") -> 30
    static func minutes(from name: DeviceActivityEvent.Name) -> Int? {
        guard name.rawValue.hasPrefix(prefix),
              let m = Int(name.rawValue.dropFirst(prefix.count)) else { return nil }
        return m
    }
}
