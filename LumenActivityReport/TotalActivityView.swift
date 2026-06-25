import SwiftUI

// Rendered inside the report extension (shown where the app embeds the report).
struct TotalActivityView: View {
    let hours: Double
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", hours))
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.95, green: 0.76, blue: 0.31)) // focus amber
            Text("hours on screen today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
