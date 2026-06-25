import DeviceActivity
import Foundation

// DeviceActivityMonitor extension principal class.
//
// Apple runs this in a tiny, short-lived, ~6 MB-budget process. It is invoked
// ONLY at the schedule boundaries and usage thresholds the APP registered via
// DeviceActivityCenter().startMonitoring(...). It is NOT handed a usage total —
// the only payload is the event NAME, into which the app encoded the minute
// threshold (e.g. "min_30"). We decode that, convert to hours, and write a
// MONOTONIC FLOOR into the SAME App Group keys the report extension uses
// (Shared/ReportContext.swift is compiled into this target too).
//
// Keep this body minimal: a single UserDefaults read + write. Heavy work,
// networking, or SwiftUI here risks the process being killed.
//
// NOTE: deliberately NO @objc(...) rename. The Info.plist principal class is the
// module-qualified `$(PRODUCT_MODULE_NAME).LumenActivityMonitor` (Apple's
// template form); an @objc rename would change the ObjC symbol to a bare name
// and break that lookup, so the extension would never instantiate.
final class LumenActivityMonitor: DeviceActivityMonitor {

    private var store: UserDefaults? { UserDefaults(suiteName: LumenScreenTime.appGroup) }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // New day / new interval: stamp today and reset the floor.
        guard let store else { return }
        store.set(LumenScreenTime.dayStamp(), forKey: LumenScreenTime.dayKey)
        store.set(0.0, forKey: LumenScreenTime.hoursKey)
        store.set(Date().timeIntervalSince1970, forKey: LumenScreenTime.updatedKey)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store?.set(Date().timeIntervalSince1970, forKey: LumenScreenTime.updatedKey)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // The event name encodes the minutes crossed, e.g. "min_30" -> 30.
        guard let minutes = LumenThresholds.minutes(from: event), let store else { return }
        let today = LumenScreenTime.dayStamp()

        // Self-heal: if intervalDidStart was missed at midnight, the stored day
        // is stale — start a fresh floor for today before applying this threshold.
        if store.string(forKey: LumenScreenTime.dayKey) != today {
            store.set(today, forKey: LumenScreenTime.dayKey)
            store.set(0.0, forKey: LumenScreenTime.hoursKey)
        }

        let hours = Double(minutes) / 60.0
        // Monotonic within the day: a late/out-of-order callback never lowers it.
        if hours > store.double(forKey: LumenScreenTime.hoursKey) {
            store.set(hours, forKey: LumenScreenTime.hoursKey)
        }
        store.set(Date().timeIntervalSince1970, forKey: LumenScreenTime.updatedKey)
    }
}
