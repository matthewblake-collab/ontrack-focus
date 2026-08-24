//
//  HealthSyncEngine.swift
//  OnTrack
//
//  Event-driven Apple Health → Supabase sync.
//
//  Replaces the old once-per-calendar-day trigger. HealthKit tells us when
//  something changed; we fetch only what changed, coalesce a burst into one
//  batch, and upload idempotently.
//
//  Flow per observer fire:
//
//    HKObserverQuery fires
//      → HKAnchoredObjectQuery from the persisted anchor for that type
//      → work out which Brisbane days the added/deleted samples touch
//      → recompute only those days' aggregates for that one type
//      → enqueue to the durable queue, persist the new anchor
//      → call the observer completion handler (data is now safe on disk)
//      → schedule a debounced flush of the whole queue
//
//  Ordering matters: the anchor advances only after the rows are durably
//  queued, and the completion handler is called only after both. A crash
//  anywhere before that simply replays the same samples next time.
//

import Foundation
import HealthKit
import Supabase
import UIKit

nonisolated final class HealthSyncEngine: @unchecked Sendable {

    static let shared = HealthSyncEngine(store: HealthSyncStore(store: UserDefaults.standard))

    /// How far back a recompute reaches when deletions are involved.
    /// `HKDeletedObject` carries only a UUID — no date — so a deletion cannot
    /// tell us which day it belonged to. This is the recompute window used in
    /// that case.
    static let deletionRecomputeDays = 30

    /// Window used only on the very first anchored fetch for a type.
    static let initialBackfillDays = 30

    private let store: HealthSyncStore
    private let healthStore = HKHealthStore()

    private let lock = NSLock()
    private var observerQueries: [HKObserverQuery] = []
    private var isStarted = false
    private var currentUserId: UUID?

    private var flushTask: Task<Void, Never>?
    private var firstPendingAt: Date?

    init(store: HealthSyncStore) {
        self.store = store
    }

    var lastAcceptedUploadAt: Date? { store.lastAcceptedUploadAt() }
    var pendingRowCount: Int { store.pendingBatch().rowCount }

    // MARK: - Lifecycle

    /// Registers one observer per sampled type and asks iOS for background
    /// delivery at the planned frequency. Safe to call repeatedly.
    func start(userId: UUID) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        lock.lock()
        currentUserId = userId
        let alreadyStarted = isStarted
        isStarted = true
        lock.unlock()

        guard !alreadyStarted else { return }

        for observed in HealthObservedTypes.all {
            guard let sampleType = Self.sampleType(for: observed.identifier) else {
                print("[HealthSync] no HKSampleType for \(observed.identifier)")
                continue
            }

            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                guard let self else {
                    // The handler must be called on every callback or iOS
                    // throttles, then stops, background delivery for this type.
                    completionHandler()
                    return
                }
                if let error {
                    print("[HealthSync] observer error for \(observed.identifier): \(error.localizedDescription)")
                    completionHandler()
                    return
                }
                self.handleObserverFire(observed: observed, completionHandler: completionHandler)
            }

            healthStore.execute(query)

            lock.lock(); observerQueries.append(query); lock.unlock()

            healthStore.enableBackgroundDelivery(
                for: sampleType,
                frequency: observed.frequency.hkFrequency
            ) { success, error in
                if !success {
                    print("[HealthSync] background delivery refused for \(observed.identifier): \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }

    /// Foreground and manual refresh take the same path as an observer fire:
    /// incremental fetch for every type, then a flush. Manual refresh uploads.
    func syncAllTypes(userId: UUID, flushImmediately: Bool) async {
        lock.lock(); currentUserId = userId; lock.unlock()

        for observed in HealthObservedTypes.all {
            await ingestChanges(for: observed)
        }

        if flushImmediately {
            await flush(userId: userId)
        } else {
            scheduleFlush(userId: userId)
        }
    }

    // MARK: - Observer handling

    private func handleObserverFire(observed: HealthObservedType, completionHandler: @escaping HKObserverQueryCompletionHandler) {
        lock.lock(); let userId = currentUserId; lock.unlock()

        guard let userId else {
            // Signed out — acknowledge so iOS keeps delivering, do nothing else.
            completionHandler()
            return
        }

        Task {
            await ingestChanges(for: observed)

            // Rows are durable now, so it is safe to acknowledge the wake-up.
            completionHandler()

            scheduleFlush(userId: userId)
        }
    }

    // MARK: - Incremental fetch

    /// Anchored fetch for one type. Enqueues whatever changed and advances the
    /// anchor only afterwards, so a crash replays rather than skips.
    /// Returns true when something was queued.
    @discardableResult
    private func ingestChanges(for observed: HealthObservedType) async -> Bool {
        guard let sampleType = Self.sampleType(for: observed.identifier) else { return false }

        let anchor = decodeAnchor(store.anchorData(forTypeIdentifier: observed.identifier))

        // With a nil anchor HealthKit returns every sample it has ever stored
        // for the type — for step count that is easily six figures. The first
        // run is therefore bounded to the same 30-day window the old daily sync
        // used; subsequent runs are true deltas and need no predicate.
        let predicate: NSPredicate? = anchor == nil
            ? HKQuery.predicateForSamples(withStart: HealthDay.date(byAddingDays: -Self.initialBackfillDays,
                                                                    to: HealthDay.startOfDay(for: Date())),
                                          end: nil)
            : nil

        let result = await anchoredFetch(sampleType: sampleType, anchor: anchor, predicate: predicate)

        let nothingChanged = result.added.isEmpty && result.deletedCount == 0
        if nothingChanged {
            // Advance anyway so an empty wake-up is not replayed forever.
            persist(anchor: result.newAnchor, for: observed.identifier)
            return false
        }

        let batch: PendingUploadBatch
        if observed.identifier == "HKWorkoutTypeIdentifier" {
            batch = PendingUploadBatch(metrics: [], workouts: await workoutRows(from: result.added))
        } else {
            let days = affectedDays(added: result.added, hadDeletions: result.deletedCount > 0)
            batch = PendingUploadBatch(
                metrics: await recomputeRows(observed: observed,
                                             days: days,
                                             emitDeletions: result.deletedCount > 0),
                workouts: []
            )
        }

        if !batch.isEmpty { store.enqueue(batch) }
        persist(anchor: result.newAnchor, for: observed.identifier)
        return !batch.isEmpty
    }

    private struct AnchoredResult {
        let added: [HKSample]
        let deletedCount: Int
        let newAnchor: HKQueryAnchor?
    }

    private func anchoredFetch(sampleType: HKSampleType, anchor: HKQueryAnchor?, predicate: NSPredicate?) async -> AnchoredResult {
        await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deleted, newAnchor, error in
                if let error {
                    print("[HealthSync] anchored fetch failed for \(sampleType.identifier): \(error.localizedDescription)")
                    // Do not advance the anchor on failure.
                    continuation.resume(returning: AnchoredResult(added: [], deletedCount: 0, newAnchor: anchor))
                    return
                }
                continuation.resume(returning: AnchoredResult(
                    added: samples ?? [],
                    deletedCount: deleted?.count ?? 0,
                    newAnchor: newAnchor
                ))
            }
            healthStore.execute(query)
        }
    }

    /// Brisbane days touched by the changed samples. Deletions carry no date,
    /// so any deletion widens the window to the last `deletionRecomputeDays`.
    private func affectedDays(added: [HKSample], hadDeletions: Bool) -> Set<Date> {
        var days = Set<Date>()
        let calendar = HealthDay.calendar

        for sample in added {
            days.insert(calendar.startOfDay(for: sample.startDate))
            days.insert(calendar.startOfDay(for: sample.endDate))
        }

        if hadDeletions {
            let today = calendar.startOfDay(for: Date())
            for offset in 0..<Self.deletionRecomputeDays {
                if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                    days.insert(day)
                }
            }
        }

        return days
    }

    /// Recomputes the affected days for one type only, reusing the same
    /// aggregation the daily sync uses so stored values stay consistent.
    private func recomputeRows(observed: HealthObservedType, days: Set<Date>, emitDeletions: Bool) async -> [PendingMetricRow] {
        guard let earliest = days.min(), let latest = days.max() else { return [] }
        let calendar = HealthDay.calendar
        let end = calendar.date(byAdding: .day, value: 1, to: latest) ?? latest

        let entries = await HealthKitManager.shared.dailyEntries(
            forObservedTypeIdentifier: observed.identifier,
            from: earliest,
            to: end
        )

        var rows = entries.map {
            PendingMetricRow(recordedAt: $0.date, metricType: $0.metricType, value: $0.value)
        }

        guard emitDeletions else { return rows }

        // A day that used to have a value and now has none must be removed
        // upstream. A nil row means "delete", never "write 0".
        let present = Set(rows.map { "\($0.recordedAt.timeIntervalSince1970)|\($0.metricType)" })
        for day in days {
            for metricType in observed.metricTypes {
                let key = "\(day.timeIntervalSince1970)|\(metricType)"
                if !present.contains(key) {
                    rows.append(PendingMetricRow(recordedAt: day, metricType: metricType, value: nil))
                }
            }
        }
        return rows
    }

    private func workoutRows(from samples: [HKSample]) async -> [PendingWorkoutRow] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = HealthDay.timeZone

        // `displayName` lives on a main-actor-isolated extension, so resolve
        // every name in one hop rather than per sample.
        let workouts = samples.compactMap { $0 as? HKWorkout }
        let names: [UUID: String] = await MainActor.run {
            Dictionary(uniqueKeysWithValues: workouts.map { ($0.uuid, $0.workoutActivityType.displayName) })
        }

        return samples.compactMap { sample in
            guard let workout = sample as? HKWorkout else { return nil }
            guard !store.hasAcceptedWorkout(workout.uuid) else { return nil }

            let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())

            return PendingWorkoutRow(
                healthKitUUID: workout.uuid,
                workoutType: names[workout.uuid] ?? "Workout",
                workoutDate: formatter.string(from: workout.startDate),
                durationMinutes: Int(workout.duration / 60),
                calories: calories.map { Int($0) }
            )
        }
    }

    // MARK: - Debounced flush

    /// Collapses a burst of observer fires into one upload.
    private func scheduleFlush(userId: UUID) {
        lock.lock()
        if firstPendingAt == nil { firstPendingAt = Date() }
        let delay = HealthSyncDebounce.delay(firstPendingAt: firstPendingAt, now: Date())
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await self?.flush(userId: userId)
        }
        lock.unlock()
    }

    /// Uploads everything queued, with retry. Only clears what Supabase
    /// accepted, and only then records the "Synced" timestamp.
    func flush(userId: UUID) async {
        let batch = store.pendingBatch().coalesced()
        guard !batch.isEmpty else {
            lock.lock(); firstPendingAt = nil; lock.unlock()
            return
        }

        await MainActor.run { HealthKitManager.shared.syncStatus = .syncing }

        let assertion = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "HealthSyncFlush")
        }

        let now = Date()
        do {
            let report = try await HealthSyncRetry.run { _ in
                try await self.upload(batch: batch, userId: userId)
            }

            store.clearAccepted(batch)
            store.markWorkoutsAccepted(batch.workouts.map(\.healthKitUUID))
            store.recordAcceptedUpload(at: now)

            lock.lock(); firstPendingAt = nil; lock.unlock()
            await MainActor.run { HealthKitManager.shared.syncStatus = .succeeded(at: now, report: report) }
        } catch {
            // The queue is left intact so the next fire, foreground or manual
            // refresh retries it. Never silently swallowed.
            let willRetry = HealthSyncPolicy.classify(error) == .transient
            let message = HealthKitManager.sanitisedSyncMessage(for: error)
            print("[HealthSync] flush failed (retryable: \(willRetry), queued rows: \(batch.rowCount)): \(message)")
            await MainActor.run {
                HealthKitManager.shared.syncStatus = .failed(message: message, willRetry: willRetry, at: now)
            }
        }

        if assertion != .invalid {
            await MainActor.run { UIApplication.shared.endBackgroundTask(assertion) }
        }
    }

    // MARK: - Upload

    private struct MetricUpsertRow: Encodable {
        let user_id: String
        let recorded_at: String
        let metric_type: String
        let value: Double
        let source: String
    }

    private struct WorkoutInsertRow: Encodable {
        let user_id: String
        let workout_type: String
        let duration_minutes: Int
        let calories: Int?
        let workout_date: String
        let source: String
    }

    private struct ExistingWorkoutRow: Decodable { let id: String }

    private func upload(batch: PendingUploadBatch, userId: UUID) async throws -> HealthSyncReport {
        let uid = userId.uuidString.lowercased()
        var counts: [String: Int] = [:]

        let writes = batch.metrics.filter { $0.value != nil }
        let deletes = batch.metrics.filter { $0.value == nil }

        if !writes.isEmpty {
            let payload = writes.map {
                MetricUpsertRow(
                    user_id: uid,
                    recorded_at: HealthSyncEngine.isoFormatter.string(from: $0.recordedAt),
                    metric_type: $0.metricType,
                    value: $0.value ?? 0,
                    source: "apple_health"
                )
            }
            do {
                try await supabase
                    .from("health_metrics")
                    .upsert(payload, onConflict: "user_id,recorded_at,metric_type")
                    .execute()
            } catch let urlError as URLError {
                throw urlError
            } catch {
                throw HealthSyncError.upload(description: "Upload rejected by the server")
            }
            for row in writes { counts[row.metricType, default: 0] += 1 }
        }

        // Deletion propagation: a sample removed in Health removes its row here.
        for row in deletes {
            do {
                try await supabase
                    .from("health_metrics")
                    .delete()
                    .eq("user_id", value: uid)
                    .eq("recorded_at", value: HealthSyncEngine.isoFormatter.string(from: row.recordedAt))
                    .eq("metric_type", value: row.metricType)
                    .execute()
            } catch let urlError as URLError {
                throw urlError
            } catch {
                throw HealthSyncError.upload(description: "Upload rejected by the server")
            }
        }

        for workout in batch.workouts {
            // `health_workout_imports` has no unique constraint, so a
            // server-side upsert is impossible without a migration. Idempotency
            // is the local UUID ledger plus this existence check.
            let existing: [ExistingWorkoutRow]
            do {
                existing = try await supabase
                    .from("health_workout_imports")
                    .select("id")
                    .eq("user_id", value: uid)
                    .eq("workout_date", value: workout.workoutDate)
                    .eq("workout_type", value: workout.workoutType)
                    .eq("duration_minutes", value: workout.durationMinutes)
                    .limit(1)
                    .execute().value
            } catch let urlError as URLError {
                throw urlError
            } catch {
                throw HealthSyncError.upload(description: "Upload rejected by the server")
            }

            guard existing.isEmpty else {
                counts["workout_skipped_duplicate", default: 0] += 1
                continue
            }

            do {
                try await supabase
                    .from("health_workout_imports")
                    .insert(WorkoutInsertRow(
                        user_id: uid,
                        workout_type: workout.workoutType,
                        duration_minutes: workout.durationMinutes,
                        calories: workout.calories,
                        workout_date: workout.workoutDate,
                        source: "apple_health"
                    ))
                    .execute()
            } catch let urlError as URLError {
                throw urlError
            } catch {
                throw HealthSyncError.upload(description: "Upload rejected by the server")
            }
            counts["workout", default: 0] += 1
        }

        for row in deletes { counts["\(row.metricType)_deleted", default: 0] += 1 }

        return HealthSyncReport(countsByMetricType: counts)
    }

    // MARK: - Helpers

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func persist(anchor: HKQueryAnchor?, for identifier: String) {
        guard let anchor else { return }
        let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        store.setAnchorData(data, forTypeIdentifier: identifier)
    }

    private func decodeAnchor(_ data: Data?) -> HKQueryAnchor? {
        guard let data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    static func sampleType(for identifier: String) -> HKSampleType? {
        if identifier == "HKWorkoutTypeIdentifier" { return HKObjectType.workoutType() }
        if identifier.hasPrefix("HKCategoryTypeIdentifier") {
            return HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier))
        }
        if identifier.hasPrefix("HKQuantityTypeIdentifier") {
            return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier))
        }
        return nil
    }
}

// MARK: - Frequency bridge

nonisolated extension HealthDeliveryFrequency {
    var hkFrequency: HKUpdateFrequency {
        switch self {
        case .immediate: return .immediate
        case .hourly: return .hourly
        }
    }
}
