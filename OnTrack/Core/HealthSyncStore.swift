//
//  HealthSyncStore.swift
//  OnTrack
//
//  Durable state for the event-driven Apple Health sync:
//
//  - per-type HKQueryAnchor persistence, so an incremental fetch resumes
//    exactly where the last one stopped rather than re-reading 30 days;
//  - a pending-upload queue that survives app launches, so rows produced
//    while offline are not lost when the process dies;
//  - a ledger of HealthKit workout UUIDs already accepted by Supabase, which
//    is how workout uploads stay idempotent without a database constraint;
//  - the timestamp of the last upload Supabase actually accepted, which is
//    what the "Synced" badge reports.
//
//  Storage is deliberately dumb (UserDefaults for small keyed blobs, one JSON
//  file for the queue) and fully injectable, so every rule is unit-testable
//  without a device.
//

import Foundation

// MARK: - Pending work

/// One row destined for `public.health_metrics`.
/// `value == nil` means the day was recomputed and now has no measurement —
/// the row must be deleted upstream, never written as 0.
nonisolated struct PendingMetricRow: Codable, Equatable, Hashable {
    let recordedAt: Date
    let metricType: String
    let value: Double?

    /// Matches the table's unique constraint (user_id is implicit — one user
    /// per device session).
    var dedupeKey: String { "\(recordedAt.timeIntervalSince1970)|\(metricType)" }
}

/// One row destined for `public.health_workout_imports`.
nonisolated struct PendingWorkoutRow: Codable, Equatable, Hashable {
    /// HealthKit's sample UUID. Not a column on the table — it is the local
    /// idempotency key, held in the accepted-workout ledger.
    let healthKitUUID: UUID
    let workoutType: String
    let workoutDate: String   // yyyy-MM-dd, Brisbane
    let durationMinutes: Int
    let calories: Int?
}

/// Everything waiting to go up, coalesced.
nonisolated struct PendingUploadBatch: Codable, Equatable {
    var metrics: [PendingMetricRow]
    var workouts: [PendingWorkoutRow]

    static let empty = PendingUploadBatch(metrics: [], workouts: [])

    var isEmpty: Bool { metrics.isEmpty && workouts.isEmpty }
    var rowCount: Int { metrics.count + workouts.count }

    /// Later rows win for the same (day, metric_type) — a recompute supersedes
    /// whatever was queued for that bucket earlier. Workouts dedupe on UUID.
    func coalesced() -> PendingUploadBatch {
        var byKey: [String: PendingMetricRow] = [:]
        var order: [String] = []
        for row in metrics {
            if byKey[row.dedupeKey] == nil { order.append(row.dedupeKey) }
            byKey[row.dedupeKey] = row
        }

        var seenWorkouts = Set<UUID>()
        var workoutsOut: [PendingWorkoutRow] = []
        for row in workouts where seenWorkouts.insert(row.healthKitUUID).inserted {
            workoutsOut.append(row)
        }

        return PendingUploadBatch(metrics: order.compactMap { byKey[$0] }, workouts: workoutsOut)
    }

    func merging(_ other: PendingUploadBatch) -> PendingUploadBatch {
        PendingUploadBatch(
            metrics: metrics + other.metrics,
            workouts: workouts + other.workouts
        ).coalesced()
    }
}

// MARK: - Key-value backing

/// Narrow seam over UserDefaults so tests never touch the real domain.
nonisolated protocol HealthSyncKeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func string(forKey key: String) -> String?
    func setString(_ value: String?, forKey key: String)
}

nonisolated extension UserDefaults: HealthSyncKeyValueStore {
    func set(_ data: Data?, forKey key: String) {
        if let data { set(data as Any, forKey: key) } else { removeObject(forKey: key) }
    }

    func setString(_ value: String?, forKey key: String) {
        if let value { set(value as Any, forKey: key) } else { removeObject(forKey: key) }
    }
}

nonisolated final class InMemoryKeyValueStore: HealthSyncKeyValueStore {
    private var storage: [String: Data] = [:]
    private var strings: [String: String] = [:]

    init() {}

    func data(forKey key: String) -> Data? { storage[key] }
    func set(_ data: Data?, forKey key: String) { storage[key] = data }
    func string(forKey key: String) -> String? { strings[key] }
    func setString(_ value: String?, forKey key: String) { strings[key] = value }
}

// MARK: - Store

nonisolated final class HealthSyncStore: @unchecked Sendable {
    private enum Key {
        static let queue = "healthkit_pending_upload_queue"
        static let acceptedWorkouts = "healthkit_accepted_workout_uuids"
        static let lastAcceptedUpload = "healthkit_last_accepted_upload_at"
        static func anchor(_ typeIdentifier: String) -> String {
            "healthkit_anchor_\(typeIdentifier)"
        }
    }

    /// A ledger this size covers years of workouts and keeps the blob small.
    static let acceptedWorkoutLedgerLimit = 2_000

    private let store: HealthSyncKeyValueStore
    private let lock = NSLock()

    init(store: HealthSyncKeyValueStore) {
        self.store = store
    }

    // MARK: Anchors

    /// Anchors are opaque `HKQueryAnchor` archives. This layer never imports
    /// HealthKit — it just keeps the bytes.
    func anchorData(forTypeIdentifier identifier: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return store.data(forKey: Key.anchor(identifier))
    }

    func setAnchorData(_ data: Data?, forTypeIdentifier identifier: String) {
        lock.lock(); defer { lock.unlock() }
        store.set(data, forKey: Key.anchor(identifier))
    }

    func clearAllAnchors(typeIdentifiers: [String]) {
        lock.lock(); defer { lock.unlock() }
        for identifier in typeIdentifiers {
            store.set(nil, forKey: Key.anchor(identifier))
        }
    }

    // MARK: Pending queue

    func pendingBatch() -> PendingUploadBatch {
        lock.lock(); defer { lock.unlock() }
        return readQueueLocked()
    }

    /// Adds work to the queue and returns the coalesced result. Survives
    /// launches because it is written through immediately.
    @discardableResult
    func enqueue(_ batch: PendingUploadBatch) -> PendingUploadBatch {
        lock.lock(); defer { lock.unlock() }
        let merged = readQueueLocked().merging(batch)
        writeQueueLocked(merged)
        return merged
    }

    /// Clears exactly what was uploaded. Anything enqueued while the upload was
    /// in flight is preserved rather than dropped.
    func clearAccepted(_ accepted: PendingUploadBatch) {
        lock.lock(); defer { lock.unlock() }
        let current = readQueueLocked()
        let acceptedMetricKeys = Set(accepted.metrics.map(\.dedupeKey))
        let acceptedWorkoutIDs = Set(accepted.workouts.map(\.healthKitUUID))

        let remaining = PendingUploadBatch(
            metrics: current.metrics.filter { !acceptedMetricKeys.contains($0.dedupeKey) },
            workouts: current.workouts.filter { !acceptedWorkoutIDs.contains($0.healthKitUUID) }
        )
        writeQueueLocked(remaining)
    }

    private func readQueueLocked() -> PendingUploadBatch {
        guard let data = store.data(forKey: Key.queue),
              let decoded = try? JSONDecoder().decode(PendingUploadBatch.self, from: data)
        else { return .empty }
        return decoded
    }

    private func writeQueueLocked(_ batch: PendingUploadBatch) {
        if batch.isEmpty {
            store.set(nil, forKey: Key.queue)
        } else if let data = try? JSONEncoder().encode(batch) {
            store.set(data, forKey: Key.queue)
        }
    }

    // MARK: Accepted-workout ledger

    /// `health_workout_imports` has no unique constraint, so a server-side
    /// upsert is impossible without a migration. Idempotency for re-fired
    /// observers is therefore held here, keyed on the HealthKit sample UUID.
    func acceptedWorkoutIDs() -> Set<UUID> {
        lock.lock(); defer { lock.unlock() }
        return readLedgerLocked()
    }

    func hasAcceptedWorkout(_ id: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return readLedgerLocked().contains(id)
    }

    func markWorkoutsAccepted(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        var ledger = readLedgerOrderedLocked()
        let existing = Set(ledger)
        for id in ids where !existing.contains(id) { ledger.append(id) }
        if ledger.count > Self.acceptedWorkoutLedgerLimit {
            ledger.removeFirst(ledger.count - Self.acceptedWorkoutLedgerLimit)
        }
        if let data = try? JSONEncoder().encode(ledger) {
            store.set(data, forKey: Key.acceptedWorkouts)
        }
    }

    private func readLedgerLocked() -> Set<UUID> {
        Set(readLedgerOrderedLocked())
    }

    private func readLedgerOrderedLocked() -> [UUID] {
        guard let data = store.data(forKey: Key.acceptedWorkouts),
              let decoded = try? JSONDecoder().decode([UUID].self, from: data)
        else { return [] }
        return decoded
    }

    // MARK: Last accepted upload

    /// Set only after Supabase accepts a batch. This is what the badge shows.
    func lastAcceptedUploadAt() -> Date? {
        lock.lock(); defer { lock.unlock() }
        guard let raw = store.string(forKey: Key.lastAcceptedUpload) else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    func recordAcceptedUpload(at date: Date) {
        lock.lock(); defer { lock.unlock() }
        store.setString(ISO8601DateFormatter().string(from: date), forKey: Key.lastAcceptedUpload)
    }
}
