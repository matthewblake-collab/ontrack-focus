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

    // MARK: - Supplement.upcomingScheduledDates(daysOfWeek:after:limit:calendar:)

    /// Regression: NotificationManager fans out one UNCalendarNotificationTrigger
    /// per future custom date. The helper must return exactly the future timestamps
    /// (no past dates), sorted ascending, capped by `limit`. 8 dates with a "now"
    /// before all of them → 8 dates back.
    func testSupplement_upcomingScheduledDates_returnsFutureOnly_sorted() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

        // Build 8 dates: 4 Mondays + 4 Thursdays in May 2026, plus 2 dates in
        // January 2026 that should be filtered as "past".
        var comps = DateComponents()
        comps.year = 2026; comps.hour = 9
        comps.month = 5
        comps.day = 4;  let mon1 = cal.date(from: comps)!
        comps.day = 7;  let thu1 = cal.date(from: comps)!
        comps.day = 11; let mon2 = cal.date(from: comps)!
        comps.day = 14; let thu2 = cal.date(from: comps)!
        comps.day = 18; let mon3 = cal.date(from: comps)!
        comps.day = 21; let thu3 = cal.date(from: comps)!
        comps.day = 25; let mon4 = cal.date(from: comps)!
        comps.day = 28; let thu4 = cal.date(from: comps)!
        comps.month = 1
        comps.day = 5;  let pastMon = cal.date(from: comps)!
        comps.day = 8;  let pastThu = cal.date(from: comps)!

        // Stored unsorted to prove the helper sorts.
        let allDates = [thu2, mon1, pastMon, mon3, thu1, mon4, pastThu, thu4, mon2, thu3]
        let payload = allDates.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
        let dow = "custom|\(payload)"

        // "now" is set to 2026-05-01 — past dates should be dropped, future kept.
        comps.year = 2026; comps.month = 5; comps.day = 1
        let now = cal.date(from: comps)!

        let upcoming = Supplement.upcomingScheduledDates(
            daysOfWeek: dow,
            after: now,
            limit: 30,
            calendar: cal
        )

        XCTAssertEqual(upcoming.count, 8, "expected 8 future dates, dropped 2 past")
        XCTAssertEqual(upcoming, [mon1, thu1, mon2, thu2, mon3, thu3, mon4, thu4],
                       "must be sorted ascending")
    }

    func testSupplement_upcomingScheduledDates_respectsLimit() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var comps = DateComponents(); comps.year = 2026; comps.month = 5; comps.hour = 9
        comps.day = 1; let now = cal.date(from: comps)!
        // 10 sequential days
        let dates: [Date] = (4...13).map { day in
            comps.day = day
            return cal.date(from: comps)!
        }
        let dow = "custom|" + dates.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
        let upcoming = Supplement.upcomingScheduledDates(daysOfWeek: dow, after: now, limit: 5, calendar: cal)
        XCTAssertEqual(upcoming.count, 5, "limit must cap")
        XCTAssertEqual(upcoming, Array(dates.prefix(5)))
    }

    // MARK: - Supplement.customScheduledDayCount(daysOfWeek:from:to:calendar:)

    /// Regression: ProgressViewModel.adherence used a CSV-int parse that produced
    /// an empty target set for `custom|...`, so denom=0 and custom-day supplements
    /// disappeared from progress stats. The new helper must count exactly the
    /// payload dates that fall in [effectiveStart, today].
    func testSupplement_customScheduledDayCount_30dayWindow_monAndThu_returns8() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

        // 30-day window ending 2026-05-31 → 2026-05-02 to 2026-05-31 inclusive.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.hour = 9
        comps.day = 31; let today = cal.date(from: comps)!
        comps.day = 2;  let windowStart = cal.date(from: comps)!

        // All Mondays + Thursdays in May 2026: 4, 7, 11, 14, 18, 21, 25, 28 → 8 dates.
        // Plus 2 dates outside the window to prove they're excluded.
        var dates: [Date] = []
        for day in [4, 7, 11, 14, 18, 21, 25, 28] {
            comps.day = day
            dates.append(cal.date(from: comps)!)
        }
        comps.month = 4; comps.day = 30
        dates.append(cal.date(from: comps)!) // before window
        comps.month = 6; comps.day = 1
        dates.append(cal.date(from: comps)!) // after window

        let payload = dates.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
        let dow = "custom|\(payload)"

        let count = Supplement.customScheduledDayCount(
            daysOfWeek: dow,
            from: windowStart,
            to: today,
            calendar: cal
        )
        XCTAssertEqual(count, 8, "expected 8 in-window Mon+Thu dates, out-of-window dropped")
    }

    func testSupplement_customScheduledDayCount_nonCustom_returnsZero() {
        // Helper is custom-only; non-custom formats must return 0 rather than a
        // misleading partial count — callers compute those via weekday counts.
        XCTAssertEqual(Supplement.customScheduledDayCount(daysOfWeek: "everyday", from: Date(), to: Date()), 0)
        XCTAssertEqual(Supplement.customScheduledDayCount(daysOfWeek: "2,5", from: Date(), to: Date()), 0)
        XCTAssertEqual(Supplement.customScheduledDayCount(daysOfWeek: "weekly|123456", from: Date(), to: Date()), 0)
    }

    func testSupplement_upcomingScheduledDates_nonCustom_returnsEmpty() {
        // weekly|, fortnightly|, "everyday", weekday-CSV all return [] — those formats
        // need their own enumeration logic, not handled by this helper.
        XCTAssertTrue(Supplement.upcomingScheduledDates(daysOfWeek: "everyday", after: Date()).isEmpty)
        XCTAssertTrue(Supplement.upcomingScheduledDates(daysOfWeek: "2,5", after: Date()).isEmpty)
        XCTAssertTrue(Supplement.upcomingScheduledDates(daysOfWeek: "weekly|123456", after: Date()).isEmpty)
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
