import DeviceActivity
import SwiftUI

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (Double) -> TotalActivityView

    // Reduce the raw results to total screen-time hours for display in this
    // extension's own view.
    //
    // IMPORTANT: a DeviceActivityReport extension is strictly sandboxed and
    // CANNOT write to the shared App Group on a real device (it only appears to
    // work in the Simulator). So we do NOT try to hand the number to the app from
    // here — the Focus *score* is fed by the DeviceActivityMonitor extension,
    // which can write to the App Group. This view still shows the exact total.
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Double {
        let totalSeconds = await data
            .flatMap { $0.activitySegments }
            .reduce(0.0) { $0 + $1.totalActivityDuration }
        return totalSeconds / 3600
    }
}
