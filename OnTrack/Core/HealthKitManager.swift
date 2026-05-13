import Foundation
import HealthKit

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
        async let hrv = fetchQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
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
}
