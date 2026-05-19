import Foundation
import HealthKit
import Supabase

@Observable
class HealthKitManager {
    static let shared = HealthKitManager()

    var isAuthorized = false
    var sleepHours: Double? = nil
    var restingHeartRate: Double? = nil
    var heartRateVariability: Double? = nil
    var stepCount: Double? = nil
    var activeEnergy: Double? = nil
    var walkRunDistance: Double? = nil
    var exerciseMinutes: Double? = nil
    var vo2Max: Double? = nil
    var weight: Double? = nil
    var bodyFat: Double? = nil
    var height: Double? = nil
    var todayWorkoutCount: Int = 0
    var cyclingDistanceKm: Double = 0.0
    var recentWorkouts: [HKWorkout] = []

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let ids: [HKQuantityTypeIdentifier] = [
            .restingHeartRate, .heartRateVariabilitySDNN, .stepCount, .activeEnergyBurned,
            .distanceWalkingRunning, .distanceCycling, .appleExerciseTime,
            .vo2Max, .bodyMass, .bodyFatPercentage, .height
        ]
        for id in ids {
            types.insert(HKQuantityType(id))
        }
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        types.insert(HKObjectType.workoutType())
        return types
    }()

    private init() {}

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            await MainActor.run { self.isAuthorized = true }
            await fetchAll()
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
        }
    }

    func fetchAll() async {
        async let s = fetchSleep()
        async let r = fetchQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let hrv = fetchQuantityLookback(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), lookbackSeconds: 36 * 3600)
        async let st = fetchQuantity(.stepCount, unit: .count())
        async let ae = fetchQuantity(.activeEnergyBurned, unit: .kilocalorie())
        async let wr = fetchQuantity(.distanceWalkingRunning, unit: .meter())
        async let cy = fetchQuantity(.distanceCycling, unit: .meter())
        async let ex = fetchQuantity(.appleExerciseTime, unit: .minute())
        async let vo = fetchQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min"))
        async let wt = fetchQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let bf = fetchQuantity(.bodyFatPercentage, unit: .percent())
        async let ht = fetchQuantity(.height, unit: .meter())
        async let wk = fetchWorkoutCount()

        let (sleep, rhr, hrvVal, steps, energy, distance, cycling, exercise, vo2, w, fat, h, workouts) =
            await (s, r, hrv, st, ae, wr, cy, ex, vo, wt, bf, ht, wk)

        await MainActor.run {
            self.sleepHours = sleep
            self.restingHeartRate = rhr
            self.heartRateVariability = hrvVal
            self.stepCount = steps
            self.activeEnergy = energy
            self.walkRunDistance = distance.map { $0 / 1000 } // convert m to km
            self.cyclingDistanceKm = cycling.map { $0 / 1000 } ?? 0.0 // convert m to km
            self.exerciseMinutes = exercise
            self.vo2Max = vo2
            self.weight = w
            self.bodyFat = fat
            self.height = h.map { $0 * 100 } // convert m to cm
            self.todayWorkoutCount = workouts
        }

        await fetchRecentWorkouts()
    }

    // MARK: - Sleep

    private func fetchSleep() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let start = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400))
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepSamples = samples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let hours = totalSeconds / 3600
                continuation.resume(returning: hours > 0 ? hours : nil)
            }
            store.execute(query)
        }
    }

    // MARK: - Workouts

    private func fetchWorkoutCount() async -> Int {
        let type = HKObjectType.workoutType()
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            store.execute(query)
        }
    }

    func fetchRecentWorkouts() async {
        let type = HKSampleType.workoutType()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 20,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        await MainActor.run {
            self.recentWorkouts = workouts
        }
    }

    // MARK: - Generic Quantity Fetch (today)

    private func fetchQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: identifier == .restingHeartRate || identifier == .heartRateVariabilitySDNN || identifier == .vo2Max || identifier == .bodyMass || identifier == .bodyFatPercentage || identifier == .height ? .discreteMostRecent : .cumulativeSum
            ) { _, stats, _ in
                let value: Double?
                if identifier == .restingHeartRate || identifier == .heartRateVariabilitySDNN || identifier == .vo2Max || identifier == .bodyMass || identifier == .bodyFatPercentage || identifier == .height {
                    value = stats?.mostRecentQuantity()?.doubleValue(for: unit)
                } else {
                    value = stats?.sumQuantity()?.doubleValue(for: unit)
                }
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchQuantityLookback(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, lookbackSeconds: TimeInterval) async -> Double? {
        let type = HKQuantityType(identifier)
        let start = Date().addingTimeInterval(-lookbackSeconds)
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteMostRecent
            ) { _, stats, _ in
                continuation.resume(returning: stats?.mostRecentQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep Score Helper (converts hours to 1-10 scale)

    /// Maps total sleep hours to a 1–10 score for daily check-in pre-fill.
    func sleepScore() -> Int? {
        guard let hours = sleepHours else { return nil }
        switch hours {
        case ..<4: return 1
        case 4..<5: return 2
        case 5..<5.5: return 3
        case 5.5..<6: return 4
        case 6..<6.5: return 5
        case 6.5..<7: return 6
        case 7..<7.5: return 7
        case 7.5..<8: return 8
        case 8..<9: return 9
        default: return 10
        }
    }

    // MARK: - Supabase sync

    private struct HealthMetricUpsert: Encodable {
        let userId: String
        let recordedAt: String
        let metricType: String
        let value: Double
        let source: String
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case recordedAt = "recorded_at"
            case metricType = "metric_type"
            case value
            case source
        }
    }

    /// Pulls daily-bucketed HealthKit data since the last sync and upserts to `health_metrics`.
    /// Safe to call repeatedly — upsert keys on (user_id, recorded_at, metric_type).
    func syncToSupabase(userId: UUID) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let cal = Calendar.current
        let now = Date()
        let endOfToday = cal.startOfDay(for: now)
        let lastSync = (UserDefaults.standard.object(forKey: "healthkit_sync_date") as? Date)
            ?? cal.date(byAdding: .day, value: -30, to: endOfToday) ?? endOfToday
        let start = cal.startOfDay(for: lastSync)
        guard start < endOfToday else { return }

        async let stepsRows  = dailySumRows(.stepCount,           unit: .count(),                    from: start, to: endOfToday, type: "steps")
        async let calsRows   = dailySumRows(.activeEnergyBurned,  unit: .kilocalorie(),              from: start, to: endOfToday, type: "active_calories")
        async let rhrRows    = dailyRecentRows(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: endOfToday, type: "resting_hr")
        async let hrvRows    = dailyRecentRows(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli),  from: start, to: endOfToday, type: "hrv")
        async let vo2Rows    = dailyRecentRows(.vo2Max,           unit: HKUnit(from: "ml/kg*min"),   from: start, to: endOfToday, type: "vo2_max")
        async let sleepRows  = sleepDailyRows(from: start, to: endOfToday)

        let allRows = await stepsRows + calsRows + rhrRows + hrvRows + vo2Rows + sleepRows
        guard !allRows.isEmpty else {
            UserDefaults.standard.set(now, forKey: "healthkit_sync_date")
            return
        }

        let payload = allRows.map { entry in
            HealthMetricUpsert(
                userId: userId.uuidString,
                recordedAt: HealthKitManager.isoFormatter.string(from: entry.date),
                metricType: entry.metricType,
                value: entry.value,
                source: "apple_health"
            )
        }

        do {
            try await supabase
                .from("health_metrics")
                .upsert(payload, onConflict: "user_id,recorded_at,metric_type")
                .execute()
            UserDefaults.standard.set(now, forKey: "healthkit_sync_date")
        } catch {
            print("[HealthKit] Supabase sync failed: \(error)")
        }
    }

    private struct HMEntry { let date: Date; let metricType: String; let value: Double }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func dailySumRows(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date, type: String) async -> [HMEntry] {
        let qType = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: qType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: from),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [HMEntry] = []
                results?.enumerateStatistics(from: from, to: to) { stat, _ in
                    if let v = stat.sumQuantity()?.doubleValue(for: unit), v > 0 {
                        out.append(HMEntry(date: stat.startDate, metricType: type, value: v))
                    }
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }

    private func dailyRecentRows(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date, type: String) async -> [HMEntry] {
        let qType = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: qType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: Calendar.current.startOfDay(for: from),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [HMEntry] = []
                results?.enumerateStatistics(from: from, to: to) { stat, _ in
                    if let v = stat.averageQuantity()?.doubleValue(for: unit), v > 0 {
                        out.append(HMEntry(date: stat.startDate, metricType: type, value: v))
                    }
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }

    private func sleepDailyRows(from: Date, to: Date) async -> [HMEntry] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                // Bucket by "night ending" date: sample end date's calendar day.
                var deepByDay:  [Date: Double] = [:]
                var remByDay:   [Date: Double] = [:]
                var totalByDay: [Date: Double] = [:]
                let cal = Calendar.current
                for s in samples {
                    let day = cal.startOfDay(for: s.endDate)
                    let minutes = s.endDate.timeIntervalSince(s.startDate) / 60.0
                    switch s.value {
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepByDay[day, default: 0] += minutes
                        totalByDay[day, default: 0] += minutes
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remByDay[day, default: 0] += minutes
                        totalByDay[day, default: 0] += minutes
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                         HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        totalByDay[day, default: 0] += minutes
                    default:
                        break
                    }
                }
                var out: [HMEntry] = []
                for (day, m) in deepByDay  where m > 0 { out.append(HMEntry(date: day, metricType: "sleep_deep_minutes",  value: m)) }
                for (day, m) in remByDay   where m > 0 { out.append(HMEntry(date: day, metricType: "sleep_rem_minutes",   value: m)) }
                for (day, m) in totalByDay where m > 0 { out.append(HMEntry(date: day, metricType: "sleep_total_minutes", value: m)) }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }
}
