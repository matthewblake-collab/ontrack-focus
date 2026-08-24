//
//  SleepDurationTests.swift
//  OnTrackTests
//
//  Locks in the fix for the inflated sleep figure (an 11.9 h reading against a
//  real night). The interval union is the part that decides the number, so it
//  is tested directly.
//
//  Source selection is not unit-testable here: HKCategorySample.sourceRevision
//  is assigned by HealthKit and cannot be constructed in a test. It is verified
//  on device instead.
//

import XCTest
import HealthKit
@testable import OnTrack

final class SleepDurationTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_756_000_000)

    private func interval(_ startHour: Double, _ endHour: Double) -> (Date, Date) {
        (base.addingTimeInterval(startHour * 3600), base.addingTimeInterval(endHour * 3600))
    }

    // MARK: - Union

    func testMergedDuration_emptyIsZero() {
        XCTAssertEqual(HealthKitManager.mergedDuration(of: []), 0, accuracy: 0.001)
    }

    func testMergedDuration_singleInterval() {
        XCTAssertEqual(HealthKitManager.mergedDuration(of: [interval(0, 7.5)]), 7.5 * 3600, accuracy: 0.001)
    }

    func testMergedDuration_disjointIntervalsAdd() {
        // Core 0–3, REM 3–5, Deep 5–7 — disjoint stages, so 7 hours total.
        let stages = [interval(0, 3), interval(3, 5), interval(5, 7)]
        XCTAssertEqual(HealthKitManager.mergedDuration(of: stages), 7 * 3600, accuracy: 0.001)
    }

    /// The exact double-count that produced the inflated card value: one writer
    /// records a single "asleep" block while another records the stages inside
    /// it. Summing gives 14 h for a 7 h night; the union gives 7 h.
    func testMergedDuration_overlappingSamplesCountedOnce() {
        let unspecified = interval(0, 7)
        let stagesInside = [interval(0, 3), interval(3, 5), interval(5, 7)]

        let summed = ([unspecified] + stagesInside)
            .reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
        XCTAssertEqual(summed, 14 * 3600, accuracy: 0.001, "the old behaviour")

        let merged = HealthKitManager.mergedDuration(of: [unspecified] + stagesInside)
        XCTAssertEqual(merged, 7 * 3600, accuracy: 0.001, "the fixed behaviour")
    }

    func testMergedDuration_partialOverlapExtendsRatherThanAdds() {
        // 0–4 and 3–6 overlap by an hour: the union is 0–6.
        XCTAssertEqual(
            HealthKitManager.mergedDuration(of: [interval(0, 4), interval(3, 6)]),
            6 * 3600,
            accuracy: 0.001
        )
    }

    func testMergedDuration_fullyContainedIntervalAddsNothing() {
        XCTAssertEqual(
            HealthKitManager.mergedDuration(of: [interval(0, 8), interval(2, 3)]),
            8 * 3600,
            accuracy: 0.001
        )
    }

    func testMergedDuration_gapBetweenSessionsIsNotCounted() {
        // Woke for an hour: 0–3 and 4–7 is 6 hours asleep, not 7.
        XCTAssertEqual(
            HealthKitManager.mergedDuration(of: [interval(0, 3), interval(4, 7)]),
            6 * 3600,
            accuracy: 0.001
        )
    }

    func testMergedDuration_unorderedInputIsHandled() {
        let shuffled = [interval(5, 7), interval(0, 3), interval(3, 5)]
        XCTAssertEqual(HealthKitManager.mergedDuration(of: shuffled), 7 * 3600, accuracy: 0.001)
    }

    func testMergedDuration_touchingIntervalsMergeWithoutGap() {
        XCTAssertEqual(
            HealthKitManager.mergedDuration(of: [interval(0, 3), interval(3, 6)]),
            6 * 3600,
            accuracy: 0.001
        )
    }

    func testMergedDuration_zeroLengthAndInvertedIntervalsIgnored() {
        let intervals = [interval(0, 7), interval(2, 2), interval(5, 4)]
        XCTAssertEqual(HealthKitManager.mergedDuration(of: intervals), 7 * 3600, accuracy: 0.001)
    }

    /// A realistic reproduction of the reported number: two writers covering
    /// the same ~7 h night summed to nearly 12 h.
    func testMergedDuration_twoWritersOverOneNightDoNotProduceTwelveHours() {
        let watch = [interval(0, 1.5), interval(1.5, 4), interval(4, 5.5), interval(5.5, 7)]
        let phone = [interval(0.2, 4.9)]

        let summed = (watch + phone).reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
        XCTAssertGreaterThan(summed / 3600, 11.0, "the old behaviour inflated past 11 h")

        let merged = HealthKitManager.mergedDuration(of: watch + phone)
        XCTAssertEqual(merged / 3600, 7.0, accuracy: 0.001)
    }

    // MARK: - Source selection

    func testPreferredSource_emptyInputReturnsEmpty() {
        XCTAssertTrue(HealthKitManager.samplesFromPreferredSource([]).isEmpty)
    }

    /// With one writer there is nothing to choose between, so every sample is
    /// kept — the filter must not silently drop a single-source night.
    func testPreferredSource_singleSourcePassesThroughUntouched() {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let samples = [
            HKCategorySample(type: type,
                             value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                             start: base,
                             end: base.addingTimeInterval(3600)),
            HKCategorySample(type: type,
                             value: HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                             start: base.addingTimeInterval(3600),
                             end: base.addingTimeInterval(7200))
        ]

        XCTAssertEqual(HealthKitManager.samplesFromPreferredSource(samples).count, 2)
    }
}
