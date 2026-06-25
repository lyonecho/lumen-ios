import Foundation
import SwiftUI
import Observation
import FamilyControls
import DeviceActivity

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
    var focusSelection = FamilyActivitySelection()
    var monitorError: String?

    @ObservationIgnored private var armedSelectionHash: Int?
    private let health = HealthStore()
    private let weightsKey = "lumen.weights"
    private let appGroup = UserDefaults(suiteName: LumenScreenTime.appGroup)

    init() {
        loadWeights()
        focusSelection = loadSelection() ?? FamilyActivitySelection()
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

    /// Pull the background floor written by the monitor extension into TODAY's
    /// metrics. Day-validated: a floor stamped for a previous day is ignored, so a
    /// missed midnight reset never shows yesterday's number. (The report extension
    /// can't write to the App Group on device, so the monitor is the sole source.)
    func ingestScreenTime() {
        guard let g = appGroup else { return }
        let fresh = g.double(forKey: LumenScreenTime.updatedKey) > 0
            && g.string(forKey: LumenScreenTime.dayKey) == LumenScreenTime.dayStamp()
        if fresh {
            let hours = g.double(forKey: LumenScreenTime.hoursKey)
            setTodayMetric("screen_hours", (hours * 100).rounded() / 100)
        } else {
            // No trustworthy data for today yet — don't let a stale value linger.
            clearTodayMetric("screen_hours")
        }
        recompute()
    }

    private func todayIndex() -> Int? {
        days.firstIndex { Calendar.current.isDateInToday($0.date) }
    }

    private func setTodayMetric(_ key: String, _ value: Double) {
        if let i = todayIndex() {
            days[i].values[key] = value
        } else {
            // Today has no HealthKit data yet — create the day so Focus still shows.
            let start = Calendar.current.startOfDay(for: Date())
            days.append(DayMetrics(date: start, values: [key: value]))
            days.sort { $0.date < $1.date }
        }
    }

    private func clearTodayMetric(_ key: String) {
        if let i = todayIndex() { days[i].values[key] = nil }
    }

    // MARK: - Background monitoring

    /// Persist the user's app/category selection to the App Group, then (re)arm
    /// the daily monitor. Call whenever the FamilyActivityPicker selection changes.
    func updateFocusSelection(_ selection: FamilyActivitySelection) {
        focusSelection = selection
        saveSelection(selection)
        startBackgroundMonitoring()
    }

    /// Register the all-day schedule + threshold ladder from the APP. The monitor
    /// extension only RECEIVES the resulting threshold callbacks in the background.
    func startBackgroundMonitoring() {
        let hasTokens = !focusSelection.applicationTokens.isEmpty
            || !focusSelection.categoryTokens.isEmpty
            || !focusSelection.webDomainTokens.isEmpty
        let center = DeviceActivityCenter()

        // Selection cleared → tear the monitor down (otherwise it keeps tracking
        // the previously-selected apps).
        guard hasTokens else {
            center.stopMonitoring([.lumenDaily])
            armedSelectionHash = nil
            monitorError = nil
            return
        }

        // Idempotent: re-arming does a stop+start which resets the threshold
        // baseline (esp. on iOS < 17.4), so only re-arm when the selection
        // actually changed since we last armed in this session.
        let hash = (try? JSONEncoder().encode(focusSelection))?.hashValue
        if let hash, hash == armedSelectionHash { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in LumenThresholds.minutes {
            let event: DeviceActivityEvent
            if #available(iOS 17.4, *) {
                event = DeviceActivityEvent(
                    applications: focusSelection.applicationTokens,
                    categories: focusSelection.categoryTokens,
                    webDomains: focusSelection.webDomainTokens,
                    threshold: DateComponents(minute: m),
                    includesPastActivity: true)
            } else {
                event = DeviceActivityEvent(
                    applications: focusSelection.applicationTokens,
                    categories: focusSelection.categoryTokens,
                    webDomains: focusSelection.webDomainTokens,
                    threshold: DateComponents(minute: m))
            }
            events[LumenThresholds.name(forMinutes: m)] = event
        }

        center.stopMonitoring([.lumenDaily])
        do {
            try center.startMonitoring(.lumenDaily, during: schedule, events: events)
            armedSelectionHash = hash
            monitorError = nil
        } catch {
            armedSelectionHash = nil
            monitorError = "Couldn't start background tracking: \(error.localizedDescription)"
        }
    }

    private func saveSelection(_ sel: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(sel) else { return }
        appGroup?.set(data, forKey: LumenScreenTime.selectionKey)
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let data = appGroup?.data(forKey: LumenScreenTime.selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
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
        // Re-overlay the background screen-time floor so a HealthKit refetch
        // doesn't drop it (and so Focus shows even on a data-sparse morning).
        ingestScreenTime()
        state = days.isEmpty ? .empty : .ready
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
