//
//  HealthSyncStoreTests.swift
//  OnTrackTests
//
//  Covers the durable state behind the event-driven sync: anchor persistence,
//  the launch-surviving upload queue, coalescing of observer bursts, the
//  workout idempotency ledger, the delivery-frequency plan and the debounce
//  window. No HealthKit, no Supabase, no device.
//

import XCTest
@testable import OnTrack

final class HealthSyncStoreTests: XCTestCase {

    private var backing: InMemoryKeyValueStore!
    private var store: HealthSyncStore!

    override func setUpWithError() throws {
        backing = InMemoryKeyValueStore()
        store = HealthSyncStore(store: backing)
    }

    // MARK: - Helpers

    private func metric(_ day: String, _ type: String, _ value: Double?) -> PendingMetricRow {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = HealthDay.timeZone
        return PendingMetricRow(recordedAt: formatter.date(from: day)!, metricType: type, value: value)
    }

    private func workout(_ id: UUID, _ date: String = "2026-08-24") -> PendingWorkoutRow {
        PendingWorkoutRow(
            healthKitUUID: id,
            workoutType: "Placeholder Activity",
            workoutDate: date,
            durationMinutes: 30,
            calories: nil
        )
    }

    // MARK: - Anchors

    func testAnchor_roundTripsPerTypeAndIsIsolated() {
        XCTAssertNil(store.anchorData(forTypeIdentifier: "HKQuantityTypeIdentifierStepCount"))

        store.setAnchorData(Data([1, 2, 3]), forTypeIdentifier: "HKQuantityTypeIdentifierStepCount")
        store.setAnchorData(Data([9]), forTypeIdentifier: "HKWorkoutTypeIdentifier")

        XCTAssertEqual(store.anchorData(forTypeIdentifier: "HKQuantityTypeIdentifierStepCount"), Data([1, 2, 3]))
        XCTAssertEqual(store.anchorData(forTypeIdentifier: "HKWorkoutTypeIdentifier"), Data([9]))
        XCTAssertNil(store.anchorData(forTypeIdentifier: "HKCategoryTypeIdentifierSleepAnalysis"))
    }

    func testAnchor_survivesANewStoreOverTheSameBacking() {
        store.setAnchorData(Data([7, 7]), forTypeIdentifier: "HKQuantityTypeIdentifierStepCount")

        let reopened = HealthSyncStore(store: backing)

        XCTAssertEqual(reopened.anchorData(forTypeIdentifier: "HKQuantityTypeIdentifierStepCount"), Data([7, 7]))
    }

    func testAnchor_clearAllResetsEveryObservedType() {
        for identifier in HealthObservedTypes.identifiers {
            store.setAnchorData(Data([1]), forTypeIdentifier: identifier)
        }

        store.clearAllAnchors(typeIdentifiers: HealthObservedTypes.identifiers)

        for identifier in HealthObservedTypes.identifiers {
            XCTAssertNil(store.anchorData(forTypeIdentifier: identifier), identifier)
        }
    }

    // MARK: - Queue durability

    func testQueue_isEmptyInitially() {
        XCTAssertTrue(store.pendingBatch().isEmpty)
    }

    func testQueue_survivesRelaunch() {
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "steps", 1200)], workouts: []))

        // A brand-new store over the same backing stands in for a fresh launch.
        let afterRelaunch = HealthSyncStore(store: backing)

        XCTAssertEqual(afterRelaunch.pendingBatch().rowCount, 1)
        XCTAssertEqual(afterRelaunch.pendingBatch().metrics.first?.metricType, "steps")
    }

    func testQueue_coalescesRepeatedFiresForTheSameBucket() {
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "steps", 1200)], workouts: []))
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "steps", 1800)], workouts: []))
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "hrv", 55)], workouts: []))

        let pending = store.pendingBatch()

        XCTAssertEqual(pending.metrics.count, 2, "one row per (day, metric_type)")
        let steps = pending.metrics.first { $0.metricType == "steps" }
        XCTAssertEqual(steps?.value, 1800, "the latest recompute wins")
    }

    func testQueue_keepsSameMetricOnDifferentDaysSeparate() {
        store.enqueue(PendingUploadBatch(metrics: [
            metric("2026-08-23", "steps", 900),
            metric("2026-08-24", "steps", 1200)
        ], workouts: []))

        XCTAssertEqual(store.pendingBatch().metrics.count, 2)
    }

    func testQueue_dedupesWorkoutsByHealthKitUUID() {
        let id = UUID()
        store.enqueue(PendingUploadBatch(metrics: [], workouts: [workout(id)]))
        store.enqueue(PendingUploadBatch(metrics: [], workouts: [workout(id)]))

        XCTAssertEqual(store.pendingBatch().workouts.count, 1, "a re-fired observer must not duplicate")
    }

    func testQueue_preservesADeletionMarkerRatherThanDroppingIt() {
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "steps", 1200)], workouts: []))
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "steps", nil)], workouts: []))

        let pending = store.pendingBatch()

        XCTAssertEqual(pending.metrics.count, 1)
        XCTAssertNil(pending.metrics.first?.value, "nil means delete the row, not write 0")
    }

    // MARK: - Clearing only what was accepted

    func testClearAccepted_removesUploadedRowsOnly() {
        let uploaded = PendingUploadBatch(metrics: [metric("2026-08-24", "steps", 1200)], workouts: [])
        store.enqueue(uploaded)
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "hrv", 55)], workouts: []))

        store.clearAccepted(uploaded)

        let remaining = store.pendingBatch()
        XCTAssertEqual(remaining.metrics.count, 1)
        XCTAssertEqual(remaining.metrics.first?.metricType, "hrv")
    }

    /// A row enqueued while an upload is in flight must not be wiped by that
    /// upload's completion — otherwise a burst mid-upload silently loses data.
    func testClearAccepted_keepsRowsEnqueuedDuringTheUpload() {
        let inFlight = PendingUploadBatch(metrics: [metric("2026-08-24", "steps", 1200)], workouts: [])
        store.enqueue(inFlight)

        // Arrives while the upload is running.
        store.enqueue(PendingUploadBatch(metrics: [metric("2026-08-24", "vo2_max", 48)], workouts: []))

        store.clearAccepted(inFlight)

        XCTAssertEqual(store.pendingBatch().metrics.map(\.metricType), ["vo2_max"])
    }

    func testClearAccepted_onEverythingEmptiesTheQueue() {
        let batch = PendingUploadBatch(metrics: [metric("2026-08-24", "steps", 1)], workouts: [workout(UUID())])
        store.enqueue(batch)

        store.clearAccepted(batch)

        XCTAssertTrue(store.pendingBatch().isEmpty)
    }

    // MARK: - Workout idempotency ledger

    func testWorkoutLedger_marksAndRecognisesAcceptedWorkouts() {
        let accepted = UUID()
        let unseen = UUID()

        XCTAssertFalse(store.hasAcceptedWorkout(accepted))
        store.markWorkoutsAccepted([accepted])

        XCTAssertTrue(store.hasAcceptedWorkout(accepted))
        XCTAssertFalse(store.hasAcceptedWorkout(unseen))
    }

    func testWorkoutLedger_survivesRelaunch() {
        let id = UUID()
        store.markWorkoutsAccepted([id])

        XCTAssertTrue(HealthSyncStore(store: backing).hasAcceptedWorkout(id))
    }

    func testWorkoutLedger_isIdempotentAndBounded() {
        let id = UUID()
        store.markWorkoutsAccepted([id])
        store.markWorkoutsAccepted([id])
        XCTAssertEqual(store.acceptedWorkoutIDs().count, 1)

        let overflow = (0..<(HealthSyncStore.acceptedWorkoutLedgerLimit + 50)).map { _ in UUID() }
        store.markWorkoutsAccepted(overflow)

        XCTAssertEqual(store.acceptedWorkoutIDs().count, HealthSyncStore.acceptedWorkoutLedgerLimit)
        XCTAssertTrue(store.hasAcceptedWorkout(overflow.last!), "the newest entries are the ones kept")
    }

    func testWorkoutLedger_emptyMarkIsANoOp() {
        store.markWorkoutsAccepted([])
        XCTAssertTrue(store.acceptedWorkoutIDs().isEmpty)
    }

    // MARK: - Last accepted upload

    func testLastAcceptedUpload_isNilUntilSupabaseAcceptsSomething() {
        XCTAssertNil(store.lastAcceptedUploadAt())
    }

    func testLastAcceptedUpload_roundTripsAndSurvivesRelaunch() {
        let at = Date(timeIntervalSince1970: 1_756_000_000)
        store.recordAcceptedUpload(at: at)

        let reopened = HealthSyncStore(store: backing)
        XCTAssertEqual(
            reopened.lastAcceptedUploadAt()?.timeIntervalSince1970 ?? 0,
            at.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - Delivery frequency plan

    func testFrequencyPlan_workoutsAndSleepAreImmediate() {
        XCTAssertEqual(HealthObservedTypes.frequency(for: "HKWorkoutTypeIdentifier"), .immediate)
        XCTAssertEqual(HealthObservedTypes.frequency(for: "HKCategoryTypeIdentifierSleepAnalysis"), .immediate)
    }

    func testFrequencyPlan_coalescedQuantityTypesAreHourly() {
        for identifier in HealthDailyMetrics.all.map(\.identifier) {
            XCTAssertEqual(HealthObservedTypes.frequency(for: identifier), .hourly, identifier)
        }
    }

    func testFrequencyPlan_unknownTypeHasNoFrequency() {
        XCTAssertNil(HealthObservedTypes.frequency(for: "HKQuantityTypeIdentifierDietaryCaffeine"))
    }

    /// The observed set covers every approved daily summary and workouts.
    func testObservedTypes_coverTheDailyRollupContractExactly() {
        let produced = Set(HealthObservedTypes.all.flatMap(\.metricTypes))
        XCTAssertEqual(produced, Set(HealthSyncPolicy.knownMetricTypes))
        XCTAssertEqual(HealthObservedTypes.all.count, 26, "24 quantity sources + sleep + workouts")
    }

    // MARK: - Debounce

    func testDebounce_firstFireWaitsTheFullWindow() {
        XCTAssertEqual(
            HealthSyncDebounce.delay(firstPendingAt: nil, now: Date()),
            HealthSyncDebounce.window,
            accuracy: 0.0001
        )
    }

    func testDebounce_aBurstExtendsTheWaitButNotPastMaxHold() {
        let start = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(
            HealthSyncDebounce.delay(firstPendingAt: start, now: start.addingTimeInterval(1)),
            HealthSyncDebounce.window,
            accuracy: 0.0001
        )

        // 9s held: only 1s of the max hold is left.
        XCTAssertEqual(
            HealthSyncDebounce.delay(firstPendingAt: start, now: start.addingTimeInterval(9)),
            1.0,
            accuracy: 0.0001
        )

        // Past the ceiling: flush now.
        XCTAssertEqual(
            HealthSyncDebounce.delay(firstPendingAt: start, now: start.addingTimeInterval(11)),
            0,
            accuracy: 0.0001
        )
    }
}
