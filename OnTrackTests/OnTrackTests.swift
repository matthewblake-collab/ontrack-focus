//
//  OnTrackTests.swift
//  OnTrackTests
//
//  Created by Matthew blake on 16/3/2026.
//

import XCTest
@testable import OnTrack

final class OnTrackTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Supplement.isScheduled(on:)

    /// Regression: protocol items with `daysOfWeek = "custom|<ts1>,<ts2>,..."` (Mon + Thu)
    /// must surface in the daily schedule on those weekdays. Previously the filter
    /// split on "," and looked for the numeric weekday (e.g. "2") in the chunks, which
    /// fails because the chunks are timestamps prefixed with "custom|".
    func testSupplement_isScheduled_customDays_matchesMondayAndThursday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

        // 2026-05-04 is a Monday, 2026-05-05 a Tuesday, 2026-05-07 a Thursday, 2026-05-08 a Friday.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.hour = 9
        comps.day = 4; let mon = cal.date(from: comps)!
        comps.day = 5; let tue = cal.date(from: comps)!
        comps.day = 7; let thu = cal.date(from: comps)!
        comps.day = 8; let fri = cal.date(from: comps)!

        // Sanity: the weekday helpers really did pick the days we think they did.
        XCTAssertEqual(cal.component(.weekday, from: mon), 2, "expected Monday (2)")
        XCTAssertEqual(cal.component(.weekday, from: thu), 5, "expected Thursday (5)")

        let payload = "\(mon.timeIntervalSince1970),\(thu.timeIntervalSince1970)"
        let supp = makeSupp(daysOfWeek: "custom|\(payload)")

        XCTAssertTrue(supp.isScheduled(on: mon, calendar: cal), "Monday must surface")
        XCTAssertTrue(supp.isScheduled(on: thu, calendar: cal), "Thursday must surface")
        XCTAssertFalse(supp.isScheduled(on: tue, calendar: cal), "Tuesday must NOT surface")
        XCTAssertFalse(supp.isScheduled(on: fri, calendar: cal), "Friday must NOT surface")
    }

    func testSupplement_isScheduled_everyday_alwaysTrue() {
        let supp = makeSupp(daysOfWeek: "everyday")
        XCTAssertTrue(supp.isScheduled(on: Date()))
    }

    func testSupplement_isScheduled_weekdayCSV_matchesByWeekday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.hour = 9
        comps.day = 4; let mon = cal.date(from: comps)!  // weekday 2
        comps.day = 7; let thu = cal.date(from: comps)!  // weekday 5
        comps.day = 5; let tue = cal.date(from: comps)!  // weekday 3

        let supp = makeSupp(daysOfWeek: "2,5") // Mon + Thu
        XCTAssertTrue(supp.isScheduled(on: mon, calendar: cal))
        XCTAssertTrue(supp.isScheduled(on: thu, calendar: cal))
        XCTAssertFalse(supp.isScheduled(on: tue, calendar: cal))
    }

    // MARK: - Helpers

    private func makeSupp(daysOfWeek: String) -> Supplement {
        Supplement(
            id: UUID(),
            userId: UUID(),
            name: "Test",
            dose: nil,
            timing: "Morning",
            customTime: nil,
            daysOfWeek: daysOfWeek,
            notes: nil,
            reminderEnabled: false,
            isActive: true,
            inProtocol: true,
            stockQuantity: nil,
            stockUnits: nil,
            doseAmount: nil,
            doseUnits: nil,
            startDate: nil,
            createdAt: Date()
        )
    }
}
