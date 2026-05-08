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

    // MARK: - Weekly / fortnightly / monthly / once recurrence

    /// `weekly|<endTs>` matches every 7 calendar days from anchor up to and
    /// including endTs.
    func testSupplement_isScheduled_weekly_stride7FromAnchor() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.hour = 9
        c.day = 4;  let anchor = cal.date(from: c)! // Mon
        c.day = 11; let nextWeek = cal.date(from: c)!
        c.day = 18; let twoWeeks = cal.date(from: c)!
        c.day = 5;  let dayAfterAnchor = cal.date(from: c)!
        c.day = 25; let beyondEnd = cal.date(from: c)!
        c.day = 18; let endTsDate = cal.date(from: c)!
        let dow = "weekly|\(endTsDate.timeIntervalSince1970)"

        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: anchor, anchor: anchor, calendar: cal))
        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: nextWeek, anchor: anchor, calendar: cal))
        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: twoWeeks, anchor: anchor, calendar: cal),
                      "endTs is inclusive on its calendar day")
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: dow, on: dayAfterAnchor, anchor: anchor, calendar: cal),
                       "off-stride day must not match")
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: dow, on: beyondEnd, anchor: anchor, calendar: cal),
                       "past endTs must not match")
    }

    func testSupplement_isScheduled_fortnightly_stride14FromAnchor() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.hour = 9
        c.day = 4;  let anchor = cal.date(from: c)! // Mon
        c.day = 11; let weekLater = cal.date(from: c)!
        c.day = 18; let twoWeeks = cal.date(from: c)!
        c.day = 30; let endTsDate = cal.date(from: c)!
        let dow = "fortnightly|\(endTsDate.timeIntervalSince1970)"

        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: anchor, anchor: anchor, calendar: cal))
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: dow, on: weekLater, anchor: anchor, calendar: cal),
                       "7-day offset must NOT match fortnightly stride")
        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: twoWeeks, anchor: anchor, calendar: cal))
    }

    func testSupplement_isScheduled_monthly_sameDayOfMonth() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 15; c.hour = 9
        let anchor = cal.date(from: c)!
        c.month = 6
        let nextMonthSameDay = cal.date(from: c)!
        c.day = 16
        let nextMonthOffByOne = cal.date(from: c)!
        c.year = 2026; c.month = 12; c.day = 15
        let endTsDate = cal.date(from: c)!
        let dow = "monthly|\(endTsDate.timeIntervalSince1970)"

        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: anchor, anchor: anchor, calendar: cal))
        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: nextMonthSameDay, anchor: anchor, calendar: cal))
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: dow, on: nextMonthOffByOne, anchor: anchor, calendar: cal))
    }

    func testSupplement_isScheduled_monthly_skipsMonthsWithoutDay31() {
        // Anchor on day 31 → February (28 days) and April (30 days) are skipped, by design.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 31; c.hour = 9
        let anchor = cal.date(from: c)!
        c.month = 2; c.day = 28
        let feb28 = cal.date(from: c)!
        c.month = 3; c.day = 31
        let mar31 = cal.date(from: c)!
        c.month = 12; c.day = 31
        let endTsDate = cal.date(from: c)!
        let dow = "monthly|\(endTsDate.timeIntervalSince1970)"

        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: dow, on: feb28, anchor: anchor, calendar: cal),
                       "Feb 28 != anchor's day-of-month 31")
        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: dow, on: mar31, anchor: anchor, calendar: cal))
    }

    func testSupplement_isScheduled_once_matchesOnlyAnchorDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 15; c.hour = 9
        let anchor = cal.date(from: c)!
        c.day = 16
        let nextDay = cal.date(from: c)!
        c.day = 14
        let dayBefore = cal.date(from: c)!
        // Time of day on the anchor day shouldn't matter — ensure midday matches too.
        c.day = 15; c.hour = 14
        let anchorAfternoon = cal.date(from: c)!

        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: "once", on: anchor, anchor: anchor, calendar: cal))
        XCTAssertTrue(Supplement.isScheduled(daysOfWeek: "once", on: anchorAfternoon, anchor: anchor, calendar: cal))
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: "once", on: nextDay, anchor: anchor, calendar: cal))
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: "once", on: dayBefore, anchor: anchor, calendar: cal))
    }

    /// Without an anchor we cannot derive a schedule for weekly/fortnightly/monthly/once.
    /// The predicate must short-circuit to `false` rather than fall back to the legacy
    /// CSV path (which would then accidentally return true for stray weekday matches).
    func testSupplement_isScheduled_noAnchor_returnsFalseForRecurrenceFormats() {
        let now = Date()
        let endTs = now.addingTimeInterval(7 * 86400).timeIntervalSince1970
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: "weekly|\(endTs)", on: now, anchor: nil))
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: "fortnightly|\(endTs)", on: now, anchor: nil))
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: "monthly|\(endTs)", on: now, anchor: nil))
        XCTAssertFalse(Supplement.isScheduled(daysOfWeek: "once", on: now, anchor: nil))
    }

    /// `scheduledDayCount` must aggregate the predicate over [from, to] inclusive.
    /// Verifies ProgressViewModel.adherence will count weekly recurrences correctly.
    func testSupplement_scheduledDayCount_weekly_30dayWindow_returns5() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.hour = 9
        c.day = 4;  let anchor = cal.date(from: c)! // Mon May 4
        c.day = 31; let endTsDate = cal.date(from: c)!
        c.day = 2;  let from = cal.date(from: c)!
        c.day = 31; let to = cal.date(from: c)!
        let dow = "weekly|\(endTsDate.timeIntervalSince1970)"
        // Mondays in May 2026: 4, 11, 18, 25 → 4 weekly hits. (May 31 is the end day
        // but isn't a multiple-of-7 day off the anchor, so it's not a hit.)
        let count = Supplement.scheduledDayCount(daysOfWeek: dow, from: from, to: to, anchor: anchor, calendar: cal)
        XCTAssertEqual(count, 4)
    }

    func testSupplement_scheduledDayCount_once_returnsOneOrZero() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 15; c.hour = 9
        let anchor = cal.date(from: c)!
        c.day = 1;  let from = cal.date(from: c)!
        c.day = 31; let to = cal.date(from: c)!
        XCTAssertEqual(
            Supplement.scheduledDayCount(daysOfWeek: "once", from: from, to: to, anchor: anchor, calendar: cal),
            1,
            "anchor inside window → 1"
        )
        c.month = 4
        c.day = 1; let earlyFrom = cal.date(from: c)!
        c.day = 30; let earlyTo = cal.date(from: c)!
        XCTAssertEqual(
            Supplement.scheduledDayCount(daysOfWeek: "once", from: earlyFrom, to: earlyTo, anchor: anchor, calendar: cal),
            0,
            "anchor outside window → 0"
        )
    }

    // MARK: - Custom-dates round-trip (storageValue <-> parseCustomDates)

    /// Round-trip: write a custom payload via the same string shape that
    /// `SupplementRecurrence.storageValue(.custom, ...)` produces, parse it back
    /// via the shared `Supplement.parseCustomDates`, then re-serialize. Verify
    /// the timestamps survive identically (set-equal, modulo Double precision).
    /// Mirrors the EditSupplementView load path so a save → reload → save cycle
    /// stays stable.
    func testSupplement_parseCustomDates_roundTripsByteEqual() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

        // 8 dates: Mon + Thu over 4 weeks of May 2026 — same shape Matt's
        // production data has.
        var c = DateComponents(); c.year = 2026; c.month = 5; c.hour = 9
        let days = [4, 7, 11, 14, 18, 21, 25, 28]
        let originals: [Date] = days.map { d in
            c.day = d
            return cal.date(from: c)!
        }

        let serialized = "custom|" + originals.map { String($0.timeIntervalSince1970) }.joined(separator: ",")

        guard let parsed = Supplement.parseCustomDates(from: serialized) else {
            XCTFail("parseCustomDates returned nil for a valid custom| payload")
            return
        }

        XCTAssertEqual(parsed.count, originals.count, "every date must round-trip")
        // Set-equal on time intervals — sorted output already matches the input.
        XCTAssertEqual(
            parsed.map { $0.timeIntervalSince1970 }.sorted(),
            originals.map { $0.timeIntervalSince1970 }.sorted()
        )

        // Re-serialize and compare to the original string. Because `String(Double)`
        // is deterministic for the same Double value, this should be byte-equal.
        let reSerialized = "custom|" + parsed.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
        XCTAssertEqual(reSerialized, serialized, "serialize → parse → serialize must be identity")
    }

    func testSupplement_parseCustomDates_nonCustom_returnsNil() {
        XCTAssertNil(Supplement.parseCustomDates(from: "everyday"))
        XCTAssertNil(Supplement.parseCustomDates(from: "2,5"))
        XCTAssertNil(Supplement.parseCustomDates(from: "weekly|123456.0"))
        XCTAssertNil(Supplement.parseCustomDates(from: "once"))
        XCTAssertNil(Supplement.parseCustomDates(from: ""))
    }

    func testSupplement_parseCustomDates_emptyPayload_returnsEmpty() {
        // "custom|" with no payload is degenerate but reachable if the picker is
        // saved with zero selected dates. Helper must return an empty array, not
        // nil — nil is reserved for "not a custom string at all".
        let parsed = Supplement.parseCustomDates(from: "custom|")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.count, 0)
    }

    func testSupplement_parseCustomDates_garbageChunksAreDropped() {
        // A single bad chunk shouldn't poison the rest — match the production
        // CSV-resilience behaviour of the predicate.
        let payload = "custom|1778162400.0,not-a-number,1779026400.0"
        let parsed = Supplement.parseCustomDates(from: payload)
        XCTAssertEqual(parsed?.count, 2)
    }

    // MARK: - Quick-fill weekday expansion (CustomSupplementDatePicker)

    /// Mon (weekday 2) + Thu (weekday 5) over 4 weeks → 8 generated dates.
    func testSupplement_expandWeekdaysToDates_monAndThu_4weeks_returns8() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.hour = 9
        c.day = 1;  let from = cal.date(from: c)!  // Fri May 1
        c.day = 28; let to = cal.date(from: c)!    // Thu May 28
        let out = Supplement.expandWeekdaysToDates(weekdays: [2, 5], from: from, to: to, calendar: cal)
        XCTAssertEqual(out.count, 8, "4 Mondays + 4 Thursdays")
        XCTAssertEqual(out, out.sorted(), "must be sorted ascending")
        // Confirm the actual days are right.
        let days = out.map { cal.component(.day, from: $0) }
        XCTAssertEqual(days, [4, 7, 11, 14, 18, 21, 25, 28])
    }

    /// Quick-fill must merge generated dates with existing manual picks (no replacement).
    /// Simulates: user manually taps two Wed dates, then quick-fills Mon+Thu — all
    /// 10 dates should be present, sorted, deduped.
    func testSupplement_quickFillMerge_preservesExistingManualPicks() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.hour = 9
        c.day = 6;  let manualWed1 = cal.date(from: c)! // Wed May 6
        c.day = 13; let manualWed2 = cal.date(from: c)! // Wed May 13
        var existing: [Date] = [manualWed1, manualWed2]

        c.day = 1;  let from = cal.date(from: c)!
        c.day = 28; let to = cal.date(from: c)!
        let generated = Supplement.expandWeekdaysToDates(weekdays: [2, 5], from: from, to: to, calendar: cal)

        // Merge logic mirrors CustomSupplementDatePicker.applyQuickFill.
        for date in generated {
            if !existing.contains(where: { cal.isDate($0, inSameDayAs: date) }) {
                existing.append(date)
            }
        }
        existing.sort()

        XCTAssertEqual(existing.count, 10, "8 generated + 2 preserved manual Wed picks")
        XCTAssertTrue(existing.contains { cal.isDate($0, inSameDayAs: manualWed1) }, "Wed May 6 must survive")
        XCTAssertTrue(existing.contains { cal.isDate($0, inSameDayAs: manualWed2) }, "Wed May 13 must survive")
    }

    /// Idempotence: running quick-fill twice with the same params must not create dupes.
    func testSupplement_quickFillMerge_isIdempotentForSameParams() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var c = DateComponents(); c.year = 2026; c.month = 5; c.hour = 9
        c.day = 1;  let from = cal.date(from: c)!
        c.day = 28; let to = cal.date(from: c)!
        var existing: [Date] = []

        for _ in 0..<2 {
            let generated = Supplement.expandWeekdaysToDates(weekdays: [2, 5], from: from, to: to, calendar: cal)
            for date in generated {
                if !existing.contains(where: { cal.isDate($0, inSameDayAs: date) }) {
                    existing.append(date)
                }
            }
        }
        XCTAssertEqual(existing.count, 8, "second pass must be a no-op")
    }

    /// Pathological inputs: 5-year window of all 7 weekdays → 365 cap kicks in.
    func testSupplement_expandWeekdaysToDates_capsAt365() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        let from = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let to = cal.date(from: DateComponents(year: 2031, month: 1, day: 1))!
        let out = Supplement.expandWeekdaysToDates(weekdays: [1, 2, 3, 4, 5, 6, 7], from: from, to: to, calendar: cal)
        XCTAssertEqual(out.count, 365, "limit must cap pathological ranges")
    }

    func testSupplement_expandWeekdaysToDates_emptyWeekdays_returnsEmpty() {
        XCTAssertTrue(Supplement.expandWeekdaysToDates(weekdays: [], from: Date(), to: Date()).isEmpty)
    }

    func testSupplement_expandWeekdaysToDates_endBeforeStart_returnsEmpty() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        XCTAssertTrue(Supplement.expandWeekdaysToDates(weekdays: [2, 5], from: now, to: yesterday).isEmpty)
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
