import Foundation
import HealthKit
import Supabase
import UIKit

@Observable
class HealthKitManager {
    static let shared = HealthKitManager()

    /// UserDefaults key holding the Brisbane day (`yyyy-MM-dd`) of the last
    /// upload that actually reached Supabase. Written only on success, so a
    /// failed sync stays retryable for the rest of the day.
    static let lastSyncSuccessDayKey = "healthkit_last_sync_success_date"

    var isAuthorized = false
    var syncStatus: HealthSyncStatus = .idle
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
            // iOS never exposes read-authorization status, so log what we can:
            // the request returned without throwing.
            print("[HealthSync] HealthKit authorization request returned; types requested=\(readTypes.count)")
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

    /// Total time asleep for LAST NIGHT only.
    ///
    /// Three bugs previously inflated this (an 11.9 h reading against a real
    /// night was the symptom):
    ///
    /// 1. The window ran from yesterday midnight to now — roughly 48 hours —
    ///    so it summed last night *and* the tail of the night before.
    /// 2. Every writer was summed together. Apple Watch, iPhone and any
    ///    third-party sleep app all counted, where Apple Health instead picks
    ///    one priority source.
    /// 3. Overlapping samples were added, so an `asleepUnspecified` block from
    ///    one writer double-counted the Core/Deep/REM it overlapped.
    ///
    /// Now: one night, bucketed by night-ending day exactly as `sleepDailyRows`
    /// does; one source; overlapping intervals unioned rather than summed.
    private func fetchSleep() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        // Wide enough to contain the whole of last night, then narrowed by the
        // night-ending bucket below.
        let calendar = HealthDay.calendar
        let targetNight = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -2, to: targetNight) ?? targetNight
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Night-ending day, matching the sleepDailyRows convention: a
                // session that crosses midnight belongs to the wake-up day.
                let lastNight = samples.filter {
                    Self.isAsleep($0) && calendar.startOfDay(for: $0.endDate) == targetNight
                }

                let chosen = Self.samplesFromPreferredSource(lastNight)
                let seconds = Self.mergedDuration(of: chosen.map { ($0.startDate, $0.endDate) })
                let hours = seconds / 3600
                continuation.resume(returning: hours > 0 ? hours : nil)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep helpers

    private static func isAsleep(_ sample: HKCategorySample) -> Bool {
        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
    }

    private static func isStagedValue(_ value: Int) -> Bool {
        value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
        value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
        value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
    }

    /// Picks ONE writer and returns only its samples. Never mixes sources —
    /// summing across writers is what produced the inflated figure.
    ///
    /// Priority: Apple Watch, then any source that writes real sleep stages,
    /// then the source with the most recorded time. Ties break on bundle id so
    /// the result is stable between runs.
    static func samplesFromPreferredSource(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        guard !samples.isEmpty else { return [] }

        let grouped = Dictionary(grouping: samples) { $0.sourceRevision.source.bundleIdentifier }
        guard grouped.count > 1 else { return samples }

        func isWatch(_ group: [HKCategorySample]) -> Bool {
            group.contains { ($0.sourceRevision.productType ?? "").hasPrefix("Watch") }
        }
        func hasStages(_ group: [HKCategorySample]) -> Bool {
            group.contains { isStagedValue($0.value) }
        }
        func totalSeconds(_ group: [HKCategorySample]) -> Double {
            mergedDuration(of: group.map { ($0.startDate, $0.endDate) })
        }

        let ranked = grouped.sorted { lhs, rhs in
            let (lKey, lGroup) = lhs
            let (rKey, rGroup) = rhs
            if isWatch(lGroup) != isWatch(rGroup) { return isWatch(lGroup) }
            if hasStages(lGroup) != hasStages(rGroup) { return hasStages(lGroup) }
            let lTotal = totalSeconds(lGroup), rTotal = totalSeconds(rGroup)
            if lTotal != rTotal { return lTotal > rTotal }
            return lKey < rKey
        }

        return ranked.first?.value ?? samples
    }

    /// Union of the intervals, so overlapping samples are counted once.
    /// Summing durations double-counts an `asleepUnspecified` block that
    /// overlaps the Core/Deep/REM stages inside it.
    static func mergedDuration(of intervals: [(Date, Date)]) -> Double {
        let valid = intervals.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        guard !valid.isEmpty else { return 0 }

        var total: Double = 0
        var currentStart = valid[0].0
        var currentEnd = valid[0].1

        for (start, end) in valid.dropFirst() {
            if start > currentEnd {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = start
                currentEnd = end
            } else if end > currentEnd {
                currentEnd = end
            }
        }
        total += currentEnd.timeIntervalSince(currentStart)
        return total
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

    // MARK: - Sync entry points

    /// True when no successful upload has happened yet today (Brisbane).
    func shouldAutoSyncToday(now: Date = Date()) -> Bool {
        HealthSyncGate.shouldAutoSync(
            lastSuccessDay: UserDefaults.standard.string(forKey: Self.lastSyncSuccessDayKey),
            today: HealthDay.dayString(for: now)
        )
    }

    /// Manual "Sync Health Now". Refreshes the on-screen values *and* uploads —
    /// the old refresh button only did the former, which is why a user tapping
    /// it never populated Supabase.
    func syncNow(userId: UUID) async {
        await fetchAll()
        // Manual refresh uploads. It takes the same incremental path as an
        // observer fire and flushes straight away rather than debouncing.
        await HealthSyncEngine.shared.syncAllTypes(userId: userId, flushImmediately: true)
    }

    /// Called on app foreground. Same path, debounced.
    func syncOnForeground(userId: UUID) async {
        await HealthSyncEngine.shared.syncAllTypes(userId: userId, flushImmediately: false)
    }

    /// Registers the HKObserverQuery set and background delivery.
    func startEventDrivenSync(userId: UUID) {
        HealthSyncEngine.shared.start(userId: userId)
    }

    /// Runs the upload with retry/backoff and keeps `syncStatus` honest.
    /// Returns nil when the sync failed. Never throws to the caller.
    @discardableResult
    func performSync(userId: UUID, now: Date = Date()) async -> HealthSyncOutcome? {
        await MainActor.run { self.syncStatus = .syncing }

        // Keep a short assertion so backgrounding mid-upload doesn't suspend us
        // before the request completes. This was a live failure mode: the sync
        // ran in a detached utility task that could be frozen on app switch.
        let assertion = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "HealthMetricsSync")
        }
        defer {
            if assertion != .invalid {
                Task { @MainActor in UIApplication.shared.endBackgroundTask(assertion) }
            }
        }

        do {
            let outcome = try await HealthSyncRetry.run { _ in
                try await self.syncToSupabase(userId: userId)
            }

            switch outcome {
            case .uploaded(let report):
                UserDefaults.standard.set(HealthDay.dayString(for: now), forKey: Self.lastSyncSuccessDayKey)
                await MainActor.run { self.syncStatus = .succeeded(at: now, report: report) }
            case .noData:
                // Not a failure, but not a success either — leave the gate open.
                await MainActor.run { self.syncStatus = .noData(at: now) }
            }
            return outcome
        } catch {
            let willRetry = HealthSyncPolicy.classify(error) == .transient
            let message = Self.sanitisedSyncMessage(for: error)
            // Counts and classes only — never a health value, never a credential.
            print("[HealthKit] Supabase sync failed (retryable: \(willRetry)): \(message)")
            await MainActor.run {
                self.syncStatus = .failed(message: message, willRetry: willRetry, at: now)
            }
            return nil
        }
    }

    /// Reduces an arbitrary error to a short, safe, user-facing string.
    /// Deliberately does not interpolate the raw error for unknown types —
    /// a PostgREST error body can echo row content back.
    nonisolated static func sanitisedSyncMessage(for error: Error) -> String {
        if let syncError = error as? HealthSyncError {
            return syncError.userFacingMessage
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No network connection"
            case .timedOut:
                return "The request timed out"
            case .userAuthenticationRequired:
                return "Sign in expired"
            default:
                return "Network error (\(urlError.code.rawValue))"
            }
        }
        return "Upload rejected by the server"
    }

    /// Pulls daily-bucketed HealthKit data since the last sync and upserts to `health_metrics`.
    /// Safe to call repeatedly — upsert keys on (user_id, recorded_at, metric_type).
    /// Throws on failure so the caller can retry; returns `.noData` when HealthKit
    /// itself had nothing in the window.
    func syncToSupabase(userId: UUID) async throws -> HealthSyncOutcome {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthSyncError.healthDataUnavailable }

        // Buckets are anchored to Australia/Brisbane midnight, not device-local,
        // so the stored `recorded_at` contract holds regardless of where the
        // phone is. Brisbane is UTC+10 with no DST.
        let cal = HealthDay.calendar
        let endOfToday = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -30, to: endOfToday) ?? endOfToday

        async let stepsRows  = dailySumRows(.stepCount,           unit: .count(),                    from: start, to: endOfToday, type: "steps")
        async let calsRows   = dailySumRows(.activeEnergyBurned,  unit: .kilocalorie(),              from: start, to: endOfToday, type: "active_calories")
        async let rhrRows    = dailyRecentRows(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: endOfToday, type: "resting_hr")
        async let hrvRows    = dailyRecentRows(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli),  from: start, to: endOfToday, type: "hrv")
        async let vo2Rows    = dailyRecentRows(.vo2Max,           unit: HKUnit(from: "ml/kg*min"),   from: start, to: endOfToday, type: "vo2_max")
        async let sleepRows  = sleepDailyRows(from: start, to: endOfToday)

        let allRows = await stepsRows + calsRows + rhrRows + hrvRows + vo2Rows + sleepRows
        guard !allRows.isEmpty else { return .noData }

        let payload = allRows.map { entry in
            HealthMetricUpsert(
                userId: userId.uuidString.lowercased(),
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
        } catch let urlError as URLError {
            // Preserve transport errors as-is so the retry policy can tell a
            // timeout (retry) from an expired session (do not retry).
            throw urlError
        } catch {
            throw HealthSyncError.upload(description: Self.sanitisedSyncMessage(for: error))
        }

        var counts: [String: Int] = [:]
        for row in allRows { counts[row.metricType, default: 0] += 1 }
        return .uploaded(HealthSyncReport(countsByMetricType: counts))
    }

    /// Recomputes one observed type's daily aggregates over an explicit window.
    /// The event-driven engine uses this so an observer fire touches only the
    /// days that actually changed, instead of re-deriving a rolling 30 days.
    func dailyEntries(forObservedTypeIdentifier identifier: String, from: Date, to: Date) async -> [(date: Date, metricType: String, value: Double)] {
        let rows: [HMEntry]
        switch identifier {
        case "HKQuantityTypeIdentifierStepCount":
            rows = await dailySumRows(.stepCount, unit: .count(), from: from, to: to, type: "steps")
        case "HKQuantityTypeIdentifierActiveEnergyBurned":
            rows = await dailySumRows(.activeEnergyBurned, unit: .kilocalorie(), from: from, to: to, type: "active_calories")
        case "HKQuantityTypeIdentifierRestingHeartRate":
            rows = await dailyRecentRows(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: from, to: to, type: "resting_hr")
        case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
            rows = await dailyRecentRows(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), from: from, to: to, type: "hrv")
        case "HKQuantityTypeIdentifierVO2Max":
            rows = await dailyRecentRows(.vo2Max, unit: HKUnit(from: "ml/kg*min"), from: from, to: to, type: "vo2_max")
        case "HKCategoryTypeIdentifierSleepAnalysis":
            rows = await sleepDailyRows(from: from, to: to)
        default:
            rows = []
        }
        return rows.map { (date: $0.date, metricType: $0.metricType, value: $0.value) }
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
                anchorDate: HealthDay.startOfDay(for: from),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [HMEntry] = []
                results?.enumerateStatistics(from: from, to: to) { stat, _ in
                    // A day with no samples yields nil and is skipped. A day
                    // genuinely measured at 0 is kept — never zero-fill a gap.
                    let v = stat.sumQuantity()?.doubleValue(for: unit)
                    if HealthSyncPolicy.shouldInclude(measured: v), let v {
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
                anchorDate: HealthDay.startOfDay(for: from),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [HMEntry] = []
                results?.enumerateStatistics(from: from, to: to) { stat, _ in
                    // Daily mean, not the latest reading. Missing days are
                    // skipped rather than written as 0.
                    let v = stat.averageQuantity()?.doubleValue(for: unit)
                    if HealthSyncPolicy.shouldInclude(measured: v), let v {
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
                guard let rawSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                // Same single-source rule as the card: never sum across
                // writers, or a second sleep app doubles every night.
                let samples = Self.samplesFromPreferredSource(rawSamples)
                // Bucket by "night ending" date: sample end date's calendar day.
                var deepByDay:  [Date: Double] = [:]
                var remByDay:   [Date: Double] = [:]
                var totalByDay: [Date: Double] = [:]
                let cal = HealthDay.calendar
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
