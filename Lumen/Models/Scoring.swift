import Foundation

// A single day's metrics, keyed by the same metric keys as the web app.
struct DayMetrics: Identifiable {
    let date: Date
    var values: [String: Double]
    var id: Date { date }
}

struct MetricResult: Identifiable {
    let def: MetricDef
    let actual: Double?
    let attainment: Double?
    var gap: Bool { attainment == nil }
    var id: String { def.key }
}

struct PillarResult: Identifiable {
    let def: PillarDef
    let score: Int
    let metrics: [MetricResult]
    let hasData: Bool
    let hasGap: Bool
    var id: PillarKey { def.key }
}

struct DayScore: Identifiable {
    let date: Date
    let pillars: [PillarResult]
    let rawScore: Int
    let score: Int
    let band: Band
    let flagged: Bool
    let flagReason: String?
    let worstPillar: PillarResult
    let bestPillar: PillarResult
    let worstMetric: MetricResult?
    var id: Date { date }
}

let RECOVERY_CAP = 49

private func clamp(_ n: Double, _ lo: Double = 0, _ hi: Double = 100) -> Double { Swift.max(lo, Swift.min(hi, n)) }

func attainment(_ def: MetricDef, _ actual: Double?) -> Double? {
    guard let a = actual, !a.isNaN else { return nil }
    switch def.direction {
    case .higherBetter:
        if def.target <= 0 { return a > 0 ? 100 : 0 }
        return clamp(100 * a / def.target)
    case .lowerBetter:
        if a <= def.target { return 100 }
        return clamp(100 * def.target / Swift.max(a, 1e-6))
    case .targetBand:
        let low = def.bandLow ?? def.target
        let high = def.bandHigh ?? def.target
        if a >= low && a <= high { return 100 }
        let distance = a < low ? low - a : a - high
        let tol = def.tolerance ?? Swift.max((high - low) / 2, 1e-6)
        return clamp(100 - (distance / tol) * 100)
    }
}

func scorePillar(_ def: PillarDef, _ values: [String: Double]) -> PillarResult {
    let results: [MetricResult] = def.metrics.map { m in
        let actual = values[m.key]
        let att = attainment(m, actual)
        return MetricResult(def: m, actual: actual, attainment: att)
    }
    let scored = results.filter { $0.attainment != nil }
    var score = 0.0
    if !scored.isEmpty {
        let wsum = scored.reduce(0.0) { $0 + $1.def.weight }
        let num = scored.reduce(0.0) { $0 + $1.def.weight * ($1.attainment ?? 0) }
        score = (num / Swift.max(wsum, 1e-6)).rounded()
    }
    return PillarResult(def: def, score: Int(clamp(score)), metrics: results,
                        hasData: !scored.isEmpty, hasGap: results.contains { $0.gap })
}

func normalizedWeights(_ weights: [PillarKey: Double]) -> [PillarKey: Double] {
    let total = PILLARS.reduce(0.0) { $0 + (weights[$1.key] ?? $1.weight) }
    var out: [PillarKey: Double] = [:]
    for p in PILLARS {
        out[p.key] = total > 0 ? (weights[p.key] ?? p.weight) / total * 100 : 0
    }
    return out
}

func scoreDay(_ day: DayMetrics, _ weights: [PillarKey: Double]) -> DayScore {
    let pillarResults = PILLARS.map { scorePillar($0, day.values) }
    let w = normalizedWeights(weights)

    // Only pillars with data count; renormalize so a partial day isn't penalized to zero.
    let active = pillarResults.filter { $0.hasData }
    let activeWeight = active.reduce(0.0) { $0 + (w[$1.def.key] ?? 0) }
    let rawScore: Int = activeWeight > 0
        ? Int(active.reduce(0.0) { $0 + (w[$1.def.key] ?? 0) / activeWeight * Double($1.score) }.rounded())
        : 0

    // Recovery cap: severe sleep debt or low blood oxygen.
    var flagged = false
    var flagReason: String? = nil
    if let sleep = day.values["sleep_hours"], sleep < 5 {
        flagged = true
        flagReason = String(format: "Severe sleep debt (%.1f h) — prioritize recovery", sleep)
    } else if let spo2 = day.values["blood_oxygen"], spo2 < 92 {
        flagged = true
        flagReason = "Low blood oxygen (\(Int(spo2.rounded()))%) — worth checking"
    }
    let score = flagged ? Swift.min(rawScore, RECOVERY_CAP) : rawScore

    let ranked = (active.isEmpty ? pillarResults : active).sorted { $0.score < $1.score }
    let worst = ranked.first!
    let best = ranked.last!
    let scoredMetrics = pillarResults.flatMap { $0.metrics }.filter { $0.attainment != nil }
    let worstMetric = scoredMetrics.min { ($0.attainment ?? 0) < ($1.attainment ?? 0) }

    return DayScore(date: day.date, pillars: pillarResults, rawScore: Int(clamp(Double(rawScore))),
                    score: Int(clamp(Double(score))), band: bandFor(score), flagged: flagged,
                    flagReason: flagReason, worstPillar: worst, bestPillar: best, worstMetric: worstMetric)
}

func trailingAvg(_ scores: [DayScore], _ i: Int, _ n: Int = 7) -> Int? {
    guard scores.indices.contains(i) else { return nil }
    let start = Swift.max(0, i - n + 1)
    let slice = scores[start...i]
    guard !slice.isEmpty else { return nil }
    return Int((slice.reduce(0) { $0 + $1.score } / slice.count))
}
