import Foundation
import HealthKit

// Wraps HealthKit: requests read authorization, then pulls per-day aggregates
// for the last N days and maps them onto Lumen's metric keys. Everything stays
// on device — HealthKit data never leaves the phone.
@MainActor
final class HealthStore {
    let store = HKHealthStore()
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private func readTypes() -> Set<HKObjectType> {
        var t = Set<HKObjectType>()
        func q(_ id: HKQuantityTypeIdentifier) { if let x = HKQuantityType.quantityType(forIdentifier: id) { t.insert(x) } }
        func c(_ id: HKCategoryTypeIdentifier) { if let x = HKCategoryType.categoryType(forIdentifier: id) { t.insert(x) } }
        q(.stepCount); q(.activeEnergyBurned); q(.appleExerciseTime)
        q(.restingHeartRate); q(.heartRateVariabilitySDNN); q(.vo2Max)
        q(.oxygenSaturation); q(.respiratoryRate); q(.dietaryWater); q(.bodyMassIndex)
        q(.heartRateRecoveryOneMinute); q(.appleSleepingWristTemperature)
        if #available(iOS 17.0, *) { q(.timeInDaylight) }
        c(.sleepAnalysis); c(.appleStandHour); c(.mindfulSession)
        return t
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes())
    }

    // MARK: - Generic statistics-collection (sum / average) bucketed by day

    private func statsByDay(_ id: HKQuantityTypeIdentifier, options: HKStatisticsOptions,
                            unit: HKUnit, days: Int) async -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [:] }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: anchor) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: options, anchorDate: anchor,
                                                intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, results, _ in
                var out: [Date: Double] = [:]
                results?.enumerateStatistics(from: start, to: Date()) { stat, _ in
                    let quantity: HKQuantity?
                    if options.contains(.cumulativeSum) { quantity = stat.sumQuantity() }
                    else { quantity = stat.averageQuantity() }
                    if let quantity {
                        out[cal.startOfDay(for: stat.startDate)] = quantity.doubleValue(for: unit)
                    }
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    // MARK: - Raw sample query

    private func samples(_ type: HKSampleType, days: Int, padStart: Int = 1) async -> [HKSample] {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1 + padStart), to: anchor) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, samples, _ in
                cont.resume(returning: samples ?? [])
            }
            store.execute(q)
        }
    }

    // MARK: - Per-metric helpers

    private func standHoursByDay(days: Int) async -> [Date: Double] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else { return [:] }
        let cal = Calendar.current
        var out: [Date: Double] = [:]
        for s in await samples(type, days: days) {
            guard let c = s as? HKCategorySample, c.value == HKCategoryValueAppleStandHour.stood.rawValue else { continue }
            out[cal.startOfDay(for: c.startDate), default: 0] += 1
        }
        return out
    }

    private func mindfulMinutesByDay(days: Int) async -> [Date: Double] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return [:] }
        let cal = Calendar.current
        var out: [Date: Double] = [:]
        for s in await samples(type, days: days) {
            out[cal.startOfDay(for: s.startDate), default: 0] += s.endDate.timeIntervalSince(s.startDate) / 60
        }
        return out
    }

    private struct SleepAgg { var asleep = 0.0; var inBed = 0.0; var deep = 0.0; var rem = 0.0; var awake = 0.0 }

    private func sleepByDay(days: Int) async -> [Date: SleepAgg] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let cal = Calendar.current
        var out: [Date: SleepAgg] = [:]
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        for s in await samples(type, days: days, padStart: 1) {
            guard let c = s as? HKCategorySample else { continue }
            let dur = c.endDate.timeIntervalSince(c.startDate)
            let wakeDay = cal.startOfDay(for: c.endDate) // belongs to the morning you woke
            var agg = out[wakeDay] ?? SleepAgg()
            if c.value == HKCategoryValueSleepAnalysis.inBed.rawValue { agg.inBed += dur }
            else if c.value == HKCategoryValueSleepAnalysis.awake.rawValue { agg.awake += dur }
            else if asleepValues.contains(c.value) {
                agg.asleep += dur
                if c.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue { agg.deep += dur }
                if c.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue { agg.rem += dur }
            }
            out[wakeDay] = agg
        }
        return out
    }

    // MARK: - Assemble

    func fetchDays(_ days: Int = 45) async -> [DayMetrics] {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let ms = HKUnit.secondUnit(with: .milli)
        let vo2Unit = HKUnit(from: "ml/kg*min")

        async let steps = statsByDay(.stepCount, options: .cumulativeSum, unit: .count(), days: days)
        async let energy = statsByDay(.activeEnergyBurned, options: .cumulativeSum, unit: .kilocalorie(), days: days)
        async let exercise = statsByDay(.appleExerciseTime, options: .cumulativeSum, unit: .minute(), days: days)
        async let water = statsByDay(.dietaryWater, options: .cumulativeSum, unit: .liter(), days: days)
        async let rhr = statsByDay(.restingHeartRate, options: .discreteAverage, unit: bpm, days: days)
        async let hrv = statsByDay(.heartRateVariabilitySDNN, options: .discreteAverage, unit: ms, days: days)
        async let resp = statsByDay(.respiratoryRate, options: .discreteAverage, unit: bpm, days: days)
        async let spo2 = statsByDay(.oxygenSaturation, options: .discreteAverage, unit: .percent(), days: days)
        async let vo2 = statsByDay(.vo2Max, options: .discreteAverage, unit: vo2Unit, days: days)
        async let bmi = statsByDay(.bodyMassIndex, options: .discreteAverage, unit: .count(), days: days)
        async let hrr = statsByDay(.heartRateRecoveryOneMinute, options: .discreteAverage, unit: bpm, days: days)
        async let wristTemp = statsByDay(.appleSleepingWristTemperature, options: .discreteAverage, unit: .degreeCelsius(), days: days)
        async let stand = standHoursByDay(days: days)
        async let mindful = mindfulMinutesByDay(days: days)
        async let sleep = sleepByDay(days: days)

        let daylight: [Date: Double]
        if #available(iOS 17.0, *) {
            daylight = await statsByDay(.timeInDaylight, options: .cumulativeSum, unit: .minute(), days: days)
        } else {
            daylight = [:]
        }

        let stepsV = await steps, energyV = await energy, exerciseV = await exercise, waterV = await water
        let rhrV = await rhr, hrvV = await hrv, respV = await resp, spo2V = await spo2
        let vo2V = await vo2, bmiV = await bmi, standV = await stand, mindfulV = await mindful, sleepV = await sleep
        let hrrV = await hrr, wristV = await wristTemp

        // Wrist temperature is a deviation signal — score the drift from your own
        // baseline (the median of recent nights), not the absolute value.
        let wristBaseline: Double? = {
            let vals = wristV.values.sorted()
            guard !vals.isEmpty else { return nil }
            return vals[vals.count / 2]
        }()

        // Union of all dates that have any data.
        var dates = Set<Date>()
        for d in [stepsV, energyV, exerciseV, waterV, rhrV, hrvV, respV, spo2V, vo2V, bmiV, standV, mindfulV, daylight, hrrV, wristV] {
            dates.formUnion(d.keys)
        }
        dates.formUnion(sleepV.keys)

        var result: [DayMetrics] = []
        for date in dates.sorted() {
            var v: [String: Double] = [:]
            func put(_ key: String, _ x: Double?) { if let x, !x.isNaN { v[key] = (x * 100).rounded() / 100 } }
            put("steps", stepsV[date])
            put("active_energy", energyV[date])
            put("exercise_minutes", exerciseV[date])
            put("hydration", waterV[date])
            put("stand_hours", standV[date])
            put("mindful_minutes", mindfulV[date])
            put("daylight_minutes", daylight[date])
            put("resting_hr", rhrV[date])
            put("hrv", hrvV[date])
            put("resp_rate", respV[date])
            if let s = spo2V[date] { put("blood_oxygen", s <= 1 ? s * 100 : s) }
            put("vo2max", vo2V[date])
            put("bmi", bmiV[date])
            put("hrr", hrrV[date])
            if let t = wristV[date], let base = wristBaseline { put("wrist_temp_dev", abs(t - base)) }
            if let sl = sleepV[date], sl.asleep > 0 {
                let inBed = sl.inBed > 0 ? sl.inBed : sl.asleep + sl.awake
                put("sleep_hours", sl.asleep / 3600)
                if inBed > 0 { put("sleep_efficiency", min(100, sl.asleep / inBed * 100)) }
                put("deep_rem_pct", min(100, (sl.deep + sl.rem) / sl.asleep * 100))
            }
            if !v.isEmpty { result.append(DayMetrics(date: date, values: v)) }
        }
        return result
    }
}
