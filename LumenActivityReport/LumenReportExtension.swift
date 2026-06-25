import DeviceActivity
import SwiftUI

// The DeviceActivityReport extension. Apple runs this in its own sandboxed
// process; it's the ONLY place that can read raw Screen Time usage. We reduce
// the day's usage to a single number and stash it in the shared App Group so the
// main app can fold it into the Life Score.
@main
struct LumenReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { hours in
            TotalActivityView(hours: hours)
        }
    }
}
