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
}
