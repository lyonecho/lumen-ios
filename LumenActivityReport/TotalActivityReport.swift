import DeviceActivity
import SwiftUI

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (Double) -> TotalActivityView

    // Reduce the raw results to total screen-time hours, then hand the number to
    // the main app through the shared App Group.
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Double {
        let totalSeconds = await data
            .flatMap { $0.activitySegments }
            .reduce(0.0) { $0 + $1.totalActivityDuration }
        let hours = totalSeconds / 3600

        if let group = UserDefaults(suiteName: LumenScreenTime.appGroup) {
            group.set(hours, forKey: LumenScreenTime.hoursKey)
            group.set(Date().timeIntervalSince1970, forKey: LumenScreenTime.updatedKey)
        }
        return hours
    }
}
