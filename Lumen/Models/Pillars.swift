import SwiftUI

enum PillarKey: String, CaseIterable, Identifiable, Codable {
    case sleep, activity, heart, mind, focus, body
    var id: String { rawValue }
}

enum Direction { case higherBetter, lowerBetter, targetBand }

enum MetricFormat { case number, percent, rating10, hours, minutes, bpm, ms, steps, kcal, liters, vo2, count }

enum MetricSource { case appleHealth, manual }

struct MetricDef: Identifiable {
    let key: String
    let name: String
    let unit: String
    let direction: Direction
    let target: Double
    var bandLow: Double? = nil
    var bandHigh: Double? = nil
    var tolerance: Double? = nil
    var weight: Double = 1
    let format: MetricFormat
    let targetText: String
    var source: MetricSource = .appleHealth
    let why: String
    var id: String { key }
}

struct PillarDef: Identifiable {
    let key: PillarKey
    let name: String
    let shortName: String
    let blurb: String
    let weight: Double
    let metrics: [MetricDef]
    var id: PillarKey { key }
    var color: Color { Palette.pillar(key) }
}

struct Band: Identifiable {
    let min: Int
    let label: String
    let color: Color
    var id: Int { min }
}

let BANDS: [Band] = [
    Band(min: 0, label: "Depleted", color: Palette.bandCritical),
    Band(min: 20, label: "Strained", color: Palette.bandAtRisk),
    Band(min: 40, label: "Steady", color: Palette.bandOnTrack),
    Band(min: 65, label: "Strong", color: Palette.bandStrong),
    Band(min: 85, label: "Peak", color: Palette.bandThriving),
]

func bandFor(_ score: Int) -> Band {
    var match = BANDS[0]
    for b in BANDS where score >= b.min { match = b }
    return match
}

// The six pillars — identical targets/weights to the web app.
let PILLARS: [PillarDef] = [
    PillarDef(key: .sleep, name: "Sleep & Recovery", shortName: "Sleep",
        blurb: "The foundation. Duration, efficiency, and restorative depth — the one pillar that can cap the whole day.",
        weight: 22,
        metrics: [
            MetricDef(key: "sleep_hours", name: "Time asleep", unit: "hours", direction: .targetBand, target: 8, bandLow: 7, bandHigh: 9, tolerance: 2, weight: 1.6, format: .hours, targetText: "7–9 h", why: "Total time actually asleep. 7–9 h is the adult band; chronic short sleep degrades nearly everything else."),
            MetricDef(key: "sleep_efficiency", name: "Sleep efficiency", unit: "%", direction: .higherBetter, target: 90, format: .percent, targetText: "≥ 90%", why: "Asleep ÷ time in bed. A low value with normal hours means fragmented sleep."),
            MetricDef(key: "deep_rem_pct", name: "Deep + REM share", unit: "%", direction: .higherBetter, target: 40, format: .percent, targetText: "≥ 40%", why: "Share of sleep in the physically and mentally restorative stages."),
            MetricDef(key: "wrist_temp_dev", name: "Wrist temp drift", unit: "°C", direction: .lowerBetter, target: 0.3, weight: 0.8, format: .number, targetText: "≤ 0.3 °C", why: "How far your overnight wrist temperature sits from your own baseline. A spike is an early flag for illness, cycle phase, or a very hard day — small drift is good. (Series 8+/Ultra.)"),
        ]),
    PillarDef(key: .activity, name: "Activity & Movement", shortName: "Activity",
        blurb: "Steps, active energy, intentional exercise, and hourly standing — the inputs you most directly control.",
        weight: 18,
        metrics: [
            MetricDef(key: "steps", name: "Steps", unit: "count", direction: .higherBetter, target: 10000, weight: 1.2, format: .steps, targetText: "≥ 10,000", why: "The baseline of non-exercise movement; even 7–8k captures most of the benefit."),
            MetricDef(key: "exercise_minutes", name: "Exercise minutes", unit: "min", direction: .higherBetter, target: 30, weight: 1.4, format: .minutes, targetText: "≥ 30 min", why: "Minutes at brisk-walk intensity or above — clears the cardio guideline."),
            MetricDef(key: "active_energy", name: "Active energy", unit: "kcal", direction: .higherBetter, target: 500, format: .kcal, targetText: "≥ 500 kcal", why: "Calories burned through movement — the Move ring."),
            MetricDef(key: "stand_hours", name: "Stand hours", unit: "count", direction: .higherBetter, target: 12, format: .count, targetText: "≥ 12 h", why: "Guards against long unbroken sitting, separate from exercise."),
        ]),
    PillarDef(key: .heart, name: "Heart & Cardio", shortName: "Heart",
        blurb: "Resting heart rate, HRV, and VO₂ max — the deepest readout of fitness and recovery.",
        weight: 18,
        metrics: [
            MetricDef(key: "resting_hr", name: "Resting heart rate", unit: "bpm", direction: .lowerBetter, target: 60, weight: 1.2, format: .bpm, targetText: "≤ 60 bpm", why: "Lower tracks better fitness; a sudden jump flags illness or overtraining."),
            MetricDef(key: "hrv", name: "Heart-rate variability", unit: "ms", direction: .higherBetter, target: 50, weight: 1.4, format: .ms, targetText: "≥ 50 ms", why: "Higher HRV means a more resilient nervous system. Read your own trend."),
            MetricDef(key: "vo2max", name: "VO₂ max", unit: "ml/kg/min", direction: .higherBetter, target: 42, format: .vo2, targetText: "≥ 42", why: "Peak aerobic capacity — a strong predictor of longevity. Moves slowly."),
            MetricDef(key: "hrr", name: "Heart-rate recovery", unit: "bpm", direction: .higherBetter, target: 30, weight: 0.9, format: .bpm, targetText: "≥ 30 bpm", why: "How many bpm your heart drops in the first minute after a workout — a bigger drop means better fitness. Only logged on workout days, so it sits out otherwise."),
        ]),
    PillarDef(key: .mind, name: "Mind & Stress", shortName: "Mind",
        blurb: "Deliberate calm and daylight — the nervous-system pillar.",
        weight: 16,
        metrics: [
            MetricDef(key: "mindful_minutes", name: "Mindful minutes", unit: "min", direction: .higherBetter, target: 10, format: .minutes, targetText: "≥ 10 min", why: "Logged Mindfulness sessions measurably lower arousal and lift HRV over time."),
            MetricDef(key: "daylight_minutes", name: "Time in daylight", unit: "min", direction: .higherBetter, target: 30, format: .minutes, targetText: "≥ 30 min", why: "Outdoor light anchors your circadian clock, lifts mood, improves sleep."),
        ]),
    PillarDef(key: .focus, name: "Focus & Screen Time", shortName: "Focus",
        blurb: "Attention as a health metric. Screen Time isn't on HealthKit, so this stays manual for now.",
        weight: 14,
        metrics: [
            MetricDef(key: "screen_hours", name: "Screen time", unit: "hours", direction: .lowerBetter, target: 3, weight: 1.4, format: .hours, targetText: "≤ 3 h", source: .manual, why: "Total iPhone screen time — a blunt but honest proxy for time on the glass."),
            MetricDef(key: "pickups", name: "Pickups", unit: "count", direction: .lowerBetter, target: 50, format: .count, targetText: "≤ 50", source: .manual, why: "How many times you picked up the phone — the texture of distraction."),
        ]),
    PillarDef(key: .body, name: "Body & Vitals", shortName: "Body",
        blurb: "Slow-moving baseline health and the vitals that catch something going wrong.",
        weight: 12,
        metrics: [
            MetricDef(key: "bmi", name: "Body mass index", unit: "BMI", direction: .targetBand, target: 21.7, bandLow: 18.5, bandHigh: 24.9, tolerance: 3, format: .number, targetText: "18.5–24.9", why: "A crude band for body composition (needs your height in Health). Pair with how you feel."),
            MetricDef(key: "hydration", name: "Hydration", unit: "L", direction: .higherBetter, target: 2.5, format: .liters, targetText: "≥ 2.5 L", why: "Water logged for the day. Mild dehydration drags energy and focus."),
            MetricDef(key: "blood_oxygen", name: "Blood oxygen", unit: "%", direction: .higherBetter, target: 96, format: .percent, targetText: "≥ 96%", why: "SpO₂ from the Watch. A persistent dip below ~92% is worth a doctor's eye."),
            MetricDef(key: "resp_rate", name: "Respiratory rate", unit: "br/min", direction: .targetBand, target: 15, bandLow: 12, bandHigh: 20, tolerance: 4, weight: 0.8, format: .count, targetText: "12–20 br/min", why: "Breaths per minute during sleep. A stable 12–20 is normal; a jump often precedes feeling sick by a day, making it a quiet early-warning vital."),
        ]),
]

let DEFAULT_WEIGHTS: [PillarKey: Double] = Dictionary(uniqueKeysWithValues: PILLARS.map { ($0.key, $0.weight) })

func formatMetric(_ value: Double?, _ format: MetricFormat) -> String {
    guard let v = value, !v.isNaN else { return "—" }
    func r(_ dp: Int) -> String { String(format: "%.\(dp)f", v) }
    switch format {
    case .percent: return "\(Int(v.rounded()))%"
    case .rating10: return r(1)
    case .hours: return "\(r(1)) h"
    case .minutes: return "\(Int(v.rounded())) min"
    case .bpm: return "\(Int(v.rounded())) bpm"
    case .ms: return "\(Int(v.rounded())) ms"
    case .steps:
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: Int(v.rounded()))) ?? "\(Int(v))"
    case .kcal: return "\(Int(v.rounded())) kcal"
    case .liters: return "\(r(1)) L"
    case .vo2: return r(1)
    case .count: return "\(Int(v.rounded()))"
    case .number: return r(1)
    }
}
