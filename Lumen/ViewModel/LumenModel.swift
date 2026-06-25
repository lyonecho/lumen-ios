import Foundation
import SwiftUI
import Observation
import FamilyControls

enum LoadState: Equatable { case idle, requesting, loading, ready, unavailable, empty }

@MainActor
@Observable
final class LumenModel {
    var days: [DayMetrics] = []
    var scores: [DayScore] = []
    var weights: [PillarKey: Double] = DEFAULT_WEIGHTS
    var selectedIndex: Int = 0
    var state: LoadState = .idle
    var didOnboard: Bool = UserDefaults.standard.bool(forKey: "lumen.didOnboard")
    var screenAuthorized: Bool = AuthorizationCenter.shared.authorizationStatus == .approved

    private let health = HealthStore()
    private let weightsKey = "lumen.weights"
    private let appGroup = UserDefaults(suiteName: LumenScreenTime.appGroup)

    init() {
        loadWeights()
        if !HealthStore.isAvailable { state = .unavailable }
    }

    // MARK: - Screen Time (Focus pillar)

    func requestScreenTime() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // User declined or unavailable — leave Focus excluded from the score.
        }
        screenAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Pull the latest total written by the report extension into today's metrics.
    func ingestScreenTime() {
        guard let g = appGroup, g.double(forKey: LumenScreenTime.updatedKey) > 0 else { return }
        let hours = g.double(forKey: LumenScreenTime.hoursKey)
        guard hours > 0, let i = days.indices.last else { return }
        days[i].values["screen_hours"] = (hours * 100).rounded() / 100
        recompute()
    }

    var currentScore: DayScore? {
        guard !scores.isEmpty else { return nil }
        return scores.indices.contains(selectedIndex) ? scores[selectedIndex] : scores.last
    }

    func connectAndLoad() async {
        guard HealthStore.isAvailable else { state = .unavailable; return }
        state = .requesting
        do {
            try await health.requestAuthorization()
            didOnboard = true
            UserDefaults.standard.set(true, forKey: "lumen.didOnboard")
            await reload()
        } catch {
            // Even if the prompt is dismissed, try to read what we can.
            didOnboard = true
            UserDefaults.standard.set(true, forKey: "lumen.didOnboard")
            await reload()
        }
    }

    func reload() async {
        state = .loading
        let fetched = await health.fetchDays(45)
        days = fetched
        recompute()
        state = fetched.isEmpty ? .empty : .ready
    }

    func recompute() {
        scores = days.map { scoreDay($0, weights) }
        selectedIndex = max(0, scores.count - 1)
    }

    // MARK: - Weights

    func setWeight(_ key: PillarKey, _ value: Double) {
        weights[key] = value
        saveWeights()
        recompute()
    }

    func resetWeights() {
        weights = DEFAULT_WEIGHTS
        saveWeights()
        recompute()
    }

    func normalizeWeights() {
        let total = PILLARS.reduce(0.0) { $0 + (weights[$1.key] ?? 0) }
        guard total > 0 else { return }
        var scaled: [PillarKey: Double] = [:]
        for p in PILLARS { scaled[p.key] = (weights[p.key] ?? 0) / total * 100 }
        // Round to whole percents, push remainder onto the largest.
        var rounded: [PillarKey: Double] = [:]
        for p in PILLARS { rounded[p.key] = (scaled[p.key] ?? 0).rounded() }
        let sum = rounded.values.reduce(0, +)
        if sum != 100, let largest = PILLARS.max(by: { (rounded[$0.key] ?? 0) < (rounded[$1.key] ?? 0) }) {
            rounded[largest.key] = (rounded[largest.key] ?? 0) + (100 - sum)
        }
        weights = rounded
        saveWeights()
        recompute()
    }

    var weightTotal: Int { Int(PILLARS.reduce(0.0) { $0 + (weights[$1.key] ?? 0) }.rounded()) }

    private func saveWeights() {
        let raw = Dictionary(uniqueKeysWithValues: weights.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(raw, forKey: weightsKey)
    }

    private func loadWeights() {
        guard let raw = UserDefaults.standard.dictionary(forKey: weightsKey) as? [String: Double] else { return }
        var w = DEFAULT_WEIGHTS
        for (k, v) in raw { if let key = PillarKey(rawValue: k) { w[key] = v } }
        weights = w
    }
}
