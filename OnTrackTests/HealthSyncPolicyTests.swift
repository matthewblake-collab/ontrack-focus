//
//  HealthSyncPolicyTests.swift
//  OnTrackTests
//
//  Covers the pure logic behind the Apple Health → Supabase sync:
//  Australia/Brisbane day bucketing, the last-SUCCESS gate, retry/backoff,
//  missing-vs-zero handling and the honest status labels.
//
//  No HealthKit and no Supabase are touched here — these are the rules the
//  sync obeys, tested in isolation so a regression shows up without a device.
//

import XCTest
@testable import OnTrack

final class HealthSyncPolicyTests: XCTestCase {

    // MARK: - Australia/Brisbane day semantics

    /// Brisbane is UTC+10 with no DST. 14:00Z is midnight the next Brisbane day,
    /// which is exactly the boundary the stored `recorded_at` buckets sit on.
    func testHealthDay_dayString_usesBrisbaneNotUTC() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]

        let justBeforeMidnight = f.date(from: "2026-08-23T13:59:59Z")!
        let exactlyMidnight = f.date(from: "2026-08-23T14:00:00Z")!
        let middleOfBrisbaneDay = f.date(from: "2026-08-24T02:00:00Z")!

        XCTAssertEqual(HealthDay.dayString(for: justBeforeMidnight), "2026-08-23")
        XCTAssertEqual(HealthDay.dayString(for: exactlyMidnight), "2026-08-24")
        XCTAssertEqual(HealthDay.dayString(for: middleOfBrisbaneDay), "2026-08-24")
    }

    /// UTC truncation of the same instants would give the wrong day for anything
    /// after 14:00Z. This test exists to lock that difference in.
    func testHealthDay_dayString_differsFromUTCTruncationAfter1400Z() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let instant = f.date(from: "2026-08-23T22:30:00Z")!

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let utcComponents = utcCal.dateComponents([.year, .month, .day], from: instant)

        XCTAssertEqual(utcComponents.day, 23, "sanity: the instant is the 23rd in UTC")
        XCTAssertEqual(HealthDay.dayString(for: instant), "2026-08-24",
                       "the same instant is the 24th in Brisbane")
    }

    func testHealthDay_startOfDay_landsOn1400ZPreviousDay() {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let middleOfBrisbaneDay = f.date(from: "2026-08-24T02:00:00Z")!

        let start = HealthDay.startOfDay(for: middleOfBrisbaneDay)

        XCTAssertEqual(f.string(from: start), "2026-08-23T14:00:00Z")
    }

    func testHealthDay_timeZone_isBrisbaneWithNoDST() {
        XCTAssertEqual(HealthDay.timeZone.identifier, "Australia/Brisbane")
        XCTAssertEqual(HealthDay.timeZone.secondsFromGMT(), 10 * 3600)
    }

    // MARK: - Auto-sync gate (last SUCCESS, never last attempt)

    func testGate_neverSynced_allowsSync() {
        XCTAssertTrue(HealthSyncGate.shouldAutoSync(lastSuccessDay: nil, today: "2026-08-24"))
    }

    func testGate_lastSuccessWasAnEarlierDay_allowsSync() {
        XCTAssertTrue(HealthSyncGate.shouldAutoSync(lastSuccessDay: "2026-08-23", today: "2026-08-24"))
    }

    func testGate_alreadySucceededToday_blocksSync() {
        XCTAssertFalse(HealthSyncGate.shouldAutoSync(lastSuccessDay: "2026-08-24", today: "2026-08-24"))
    }

    /// The original bug: the day flag was stamped before the upload ran, so one
    /// failure silently cost the whole day. A failure must leave the gate open.
    func testGate_failureDoesNotRecordSuccess_soSameDayRetryIsAllowed() {
        let store = InMemorySyncRecordStore()

        store.record(outcome: .failure, day: "2026-08-24")
        XCTAssertTrue(HealthSyncGate.shouldAutoSync(lastSuccessDay: store.lastSuccessDay, today: "2026-08-24"),
                      "a failed upload must stay retryable the same day")

        store.record(outcome: .noData, day: "2026-08-24")
        XCTAssertTrue(HealthSyncGate.shouldAutoSync(lastSuccessDay: store.lastSuccessDay, today: "2026-08-24"),
                      "no-data is not a success and must stay retryable")

        store.record(outcome: .success, day: "2026-08-24")
        XCTAssertFalse(HealthSyncGate.shouldAutoSync(lastSuccessDay: store.lastSuccessDay, today: "2026-08-24"),
                       "only a real upload closes the gate")
    }

    // MARK: - Missing vs zero

    /// A day with no samples must never be written as 0. A day genuinely measured
    /// at 0 must be written as 0. The old `> 0` filter conflated the two.
    func testShouldInclude_dropsMissingButKeepsGenuineZero() {
        XCTAssertFalse(HealthSyncPolicy.shouldInclude(measured: nil), "missing must be dropped, not zeroed")
        XCTAssertTrue(HealthSyncPolicy.shouldInclude(measured: 0), "a measured zero is real data")
        XCTAssertTrue(HealthSyncPolicy.shouldInclude(measured: 4210))
    }

    func testShouldInclude_rejectsNonFiniteValues() {
        XCTAssertFalse(HealthSyncPolicy.shouldInclude(measured: .nan))
        XCTAssertFalse(HealthSyncPolicy.shouldInclude(measured: .infinity))
    }

    // MARK: - Backoff

    func testBackoff_growsExponentiallyAndIsCapped() {
        XCTAssertEqual(HealthSyncPolicy.backoffDelay(forAttempt: 1), 1.0, accuracy: 0.0001)
        XCTAssertEqual(HealthSyncPolicy.backoffDelay(forAttempt: 2), 2.0, accuracy: 0.0001)
        XCTAssertEqual(HealthSyncPolicy.backoffDelay(forAttempt: 3), 4.0, accuracy: 0.0001)
        XCTAssertEqual(HealthSyncPolicy.backoffDelay(forAttempt: 9), HealthSyncPolicy.maxDelay, accuracy: 0.0001)
    }

    func testBackoff_attemptZeroOrNegativeIsClamped() {
        XCTAssertEqual(HealthSyncPolicy.backoffDelay(forAttempt: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(HealthSyncPolicy.backoffDelay(forAttempt: -5), 1.0, accuracy: 0.0001)
    }

    // MARK: - Error classification

    func testClassify_networkErrorsAreTransient() {
        XCTAssertEqual(HealthSyncPolicy.classify(URLError(.timedOut)), .transient)
        XCTAssertEqual(HealthSyncPolicy.classify(URLError(.networkConnectionLost)), .transient)
        XCTAssertEqual(HealthSyncPolicy.classify(URLError(.notConnectedToInternet)), .transient)
    }

    func testClassify_authorizationFailuresArePermanent() {
        XCTAssertEqual(HealthSyncPolicy.classify(HealthSyncError.notSignedIn), .permanent)
        XCTAssertEqual(HealthSyncPolicy.classify(HealthSyncError.healthDataUnavailable), .permanent)
        XCTAssertEqual(HealthSyncPolicy.classify(URLError(.userAuthenticationRequired)), .permanent)
    }

    // MARK: - Retry runner

    func testRetry_succeedsFirstTime_doesNotSleep() async throws {
        let sleeper = SleepSpy()
        var attempts = 0

        let result = try await HealthSyncRetry.run(sleep: sleeper.sleep) { _ in
            attempts += 1
            return 42
        }

        XCTAssertEqual(result, 42)
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(sleeper.delays, [])
    }

    func testRetry_transientFailureThenSuccess_backsOffOnce() async throws {
        let sleeper = SleepSpy()
        var attempts = 0

        let result = try await HealthSyncRetry.run(sleep: sleeper.sleep) { _ in
            attempts += 1
            if attempts == 1 { throw URLError(.timedOut) }
            return "ok"
        }

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(sleeper.delays, [1.0])
    }

    func testRetry_permanentFailure_doesNotRetry() async {
        let sleeper = SleepSpy()
        var attempts = 0

        do {
            _ = try await HealthSyncRetry.run(sleep: sleeper.sleep) { _ in
                attempts += 1
                throw HealthSyncError.notSignedIn
            }
            XCTFail("expected the permanent error to be rethrown")
        } catch {
            XCTAssertTrue(error is HealthSyncError)
        }

        XCTAssertEqual(attempts, 1, "a permanent failure must not be retried")
        XCTAssertEqual(sleeper.delays, [])
    }

    func testRetry_exhaustsMaxAttemptsThenThrows() async {
        let sleeper = SleepSpy()
        var attempts = 0

        do {
            _ = try await HealthSyncRetry.run(sleep: sleeper.sleep) { _ in
                attempts += 1
                throw URLError(.networkConnectionLost)
            }
            XCTFail("expected the last error to be rethrown")
        } catch {
            XCTAssertTrue(error is URLError)
        }

        XCTAssertEqual(attempts, HealthSyncPolicy.maxAttempts)
        XCTAssertEqual(sleeper.delays, [1.0, 2.0], "sleeps between attempts, never after the last one")
    }

    // MARK: - Status is honest

    func testStatus_labels() {
        let at = Date(timeIntervalSince1970: 1_756_000_000)

        XCTAssertEqual(HealthSyncStatus.idle.label, "Not synced yet")
        XCTAssertEqual(HealthSyncStatus.syncing.label, "Syncing…")

        let report = HealthSyncReport(countsByMetricType: ["steps": 30, "hrv": 28])
        let ok = HealthSyncStatus.succeeded(at: at, report: report)
        XCTAssertTrue(ok.label.hasPrefix("Synced 58 rows across 2 metrics"), "got: \(ok.label)")

        XCTAssertEqual(HealthSyncStatus.noData(at: at).label,
                       "No Health data found to sync — check Health permissions for OnTrack")

        let retrying = HealthSyncStatus.failed(message: "Network offline", willRetry: true, at: at)
        XCTAssertEqual(retrying.label, "Sync failed: Network offline — will retry")

        let terminal = HealthSyncStatus.failed(message: "Not signed in", willRetry: false, at: at)
        XCTAssertEqual(terminal.label, "Sync failed: Not signed in")
    }

    func testStatus_isBusyOnlyWhileSyncing() {
        XCTAssertTrue(HealthSyncStatus.syncing.isBusy)
        XCTAssertFalse(HealthSyncStatus.idle.isBusy)
        XCTAssertFalse(HealthSyncStatus.noData(at: Date()).isBusy)
    }

    // MARK: - Report

    func testReport_totalsRowsAndCountsDistinctMetricTypes() {
        let report = HealthSyncReport(countsByMetricType: [
            "steps": 30,
            "active_calories": 30,
            "sleep_total_minutes": 21
        ])

        XCTAssertEqual(report.rowCount, 81)
        XCTAssertEqual(report.metricTypeCount, 3)
    }

    func testReport_emptyIsNotASuccessfulUpload() {
        XCTAssertEqual(HealthSyncReport(countsByMetricType: [:]).rowCount, 0)
        XCTAssertTrue(HealthSyncReport(countsByMetricType: [:]).isEmpty)
    }

    // MARK: - Comprehensive daily-rollup contract

    func testMetricTypeVocabulary_coversEveryApprovedNumericDailyRollup() {
        XCTAssertEqual(HealthSyncPolicy.knownMetricTypes.count, 27)
        XCTAssertTrue(Set([
            "heart_rate",
            "resting_hr",
            "hrv",
            "heart_rate_recovery_one_minute",
            "oxygen_saturation",
            "sleeping_wrist_temperature",
            "respiratory_rate",
            "vo2_max",
            "steps",
            "active_calories",
            "basal_calories",
            "exercise_minutes",
            "stand_minutes",
            "walk_run_distance_km",
            "cycling_distance_km",
            "swimming_distance_m",
            "body_mass_kg",
            "body_fat_percentage",
            "lean_body_mass_kg",
            "height_cm",
            "walking_speed_m_s",
            "walking_asymmetry_percentage",
            "walking_steadiness_percentage",
            "six_minute_walk_distance_m",
            "sleep_deep_minutes",
            "sleep_rem_minutes",
            "sleep_total_minutes"
        ]).isSubset(of: Set(HealthSyncPolicy.knownMetricTypes)))
    }

    func testDailyMetricCatalog_hasUniqueIdentifiersAndMetricTypes() {
        XCTAssertEqual(Set(HealthDailyMetrics.all.map(\.identifier)).count, HealthDailyMetrics.all.count)
        XCTAssertEqual(Set(HealthDailyMetrics.all.map(\.metricType)).count, HealthDailyMetrics.all.count)
        XCTAssertEqual(HealthDailyMetrics.all.count, 24)
    }

    func testDailyMetricCatalog_preservesLegacyVocabularyForExistingRows() {
        XCTAssertEqual(HealthDailyMetrics.metricType(for: "HKQuantityTypeIdentifierStepCount"), "steps")
        XCTAssertEqual(HealthDailyMetrics.metricType(for: "HKQuantityTypeIdentifierActiveEnergyBurned"), "active_calories")
        XCTAssertEqual(HealthDailyMetrics.metricType(for: "HKQuantityTypeIdentifierRestingHeartRate"), "resting_hr")
        XCTAssertEqual(HealthDailyMetrics.metricType(for: "HKQuantityTypeIdentifierHeartRateVariabilitySDNN"), "hrv")
        XCTAssertEqual(HealthDailyMetrics.metricType(for: "HKQuantityTypeIdentifierVO2Max"), "vo2_max")
    }

    // MARK: - Historical comparison backfill

    func testHistoryWindow_usesOneYearUntilTheFirstBackfillCompletes() {
        XCTAssertEqual(
            HealthSyncPolicy.lookbackDays(historicalBackfillCompleted: false),
            365
        )
    }

    func testHistoryWindow_returnsToRollingRefreshAfterBackfill() {
        XCTAssertEqual(
            HealthSyncPolicy.lookbackDays(historicalBackfillCompleted: true),
            30
        )
    }

    func testUploadBatches_keepTheHistoricalPayloadBounded() {
        XCTAssertEqual(HealthSyncPolicy.uploadBatchSize, 500)
        XCTAssertEqual(HealthSyncPolicy.uploadRanges(rowCount: 0), [])
        XCTAssertEqual(
            HealthSyncPolicy.uploadRanges(rowCount: 1_201),
            [0..<500, 500..<1_000, 1_000..<1_201]
        )
    }
}

// MARK: - Test doubles

/// Records the delays a retry run asked for instead of actually sleeping,
/// so the retry tests run instantly and deterministically.
private final class SleepSpy: @unchecked Sendable {
    private(set) var delays: [TimeInterval] = []

    @Sendable
    func sleep(_ seconds: TimeInterval) async throws {
        delays.append(seconds)
    }
}

/// Stands in for UserDefaults so the gate can be tested without touching disk.
private final class InMemorySyncRecordStore {
    enum Outcome { case success, failure, noData }

    private(set) var lastSuccessDay: String?

    func record(outcome: Outcome, day: String) {
        guard case .success = outcome else { return }
        lastSuccessDay = day
    }
}
