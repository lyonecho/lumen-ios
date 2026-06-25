import SwiftUI

// Color palette ported from the web app's design tokens (oklch → approx sRGB).
extension Color {
    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xff) / 255
        let g = Double((v >> 8) & 0xff) / 255
        let b = Double(v & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum Palette {
    static let bgApp = Color(hex: "14171C")
    static let bgSurface = Color(hex: "1B1F26")
    static let bgInset = Color(hex: "181B21")
    static let bgRaised = Color(hex: "222732")
    static let border = Color(hex: "2B2F37")

    static let textPrimary = Color(hex: "F2F4F8")
    static let textSecondary = Color(hex: "B9C0CC")
    static let textMuted = Color(hex: "8A93A1")
    static let textFaint = Color(hex: "5A626E")

    static let accent = Color(hex: "54C1F0")

    // Pillars
    static let sleep = Color(hex: "9B8CFF")
    static let activity = Color(hex: "3FD18B")
    static let heart = Color(hex: "FF6B81")
    static let mind = Color(hex: "54C1F0")
    static let focus = Color(hex: "F2C14E")
    static let body = Color(hex: "46C9D6")

    // Score bands
    static let bandCritical = Color(hex: "FF4D5E")
    static let bandAtRisk = Color(hex: "FF9F43")
    static let bandOnTrack = Color(hex: "FFD23F")
    static let bandStrong = Color(hex: "33D99B")
    static let bandThriving = Color(hex: "37C6FF")

    static func pillar(_ k: PillarKey) -> Color {
        switch k {
        case .sleep: return sleep
        case .activity: return activity
        case .heart: return heart
        case .mind: return mind
        case .focus: return focus
        case .body: return body
        }
    }

    static func pillarIcon(_ k: PillarKey) -> String {
        switch k {
        case .sleep: return "moon.zzz.fill"
        case .activity: return "figure.run"
        case .heart: return "heart.fill"
        case .mind: return "brain.head.profile"
        case .focus: return "iphone"
        case .body: return "drop.fill"
        }
    }
}
