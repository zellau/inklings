import XCTest
@testable import InklingsLib

final class WritingDayTests: XCTestCase {
    
    let eastern = TimeZone(identifier: "America/New_York")!
    let pacific = TimeZone(identifier: "America/Los_Angeles")!
    
    /// Helper to create a date from components in a specific timezone
    func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, timezone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
    
    func testMiddleOfDay() {
        // 2pm on Jan 15 should be Jan 15
        let date = makeDate(year: 2024, month: 1, day: 15, hour: 14, timezone: eastern)
        XCTAssertEqual(getWritingDay(for: date, timezone: eastern), "2024-01-15")
    }
    
    func testJustAfterMidnight() {
        // 1am on Jan 15 should still be Jan 14 (before 3am boundary)
        let date = makeDate(year: 2024, month: 1, day: 15, hour: 1, timezone: eastern)
        XCTAssertEqual(getWritingDay(for: date, timezone: eastern), "2024-01-14")
    }
    
    func testJustBefore3am() {
        // 2:59am on Jan 15 should still be Jan 14
        let date = makeDate(year: 2024, month: 1, day: 15, hour: 2, minute: 59, timezone: eastern)
        XCTAssertEqual(getWritingDay(for: date, timezone: eastern), "2024-01-14")
    }
    
    func testExactly3am() {
        // 3:00am on Jan 15 should be Jan 15
        let date = makeDate(year: 2024, month: 1, day: 15, hour: 3, minute: 0, timezone: eastern)
        XCTAssertEqual(getWritingDay(for: date, timezone: eastern), "2024-01-15")
    }
    
    func testDifferentTimezonesSameInstant() {
        // 1am Eastern = 10pm Pacific (previous day)
        // At 1am Eastern on Jan 15:
        //   - Eastern: writing day is Jan 14 (before 3am)
        //   - Pacific: it's 10pm on Jan 14, writing day is Jan 14
        let date = makeDate(year: 2024, month: 1, day: 15, hour: 1, timezone: eastern)
        XCTAssertEqual(getWritingDay(for: date, timezone: eastern), "2024-01-14")
        XCTAssertEqual(getWritingDay(for: date, timezone: pacific), "2024-01-14")
    }
    
    func testYearBoundary() {
        // 2am on Jan 1 should be Dec 31 of previous year
        let date = makeDate(year: 2024, month: 1, day: 1, hour: 2, timezone: eastern)
        XCTAssertEqual(getWritingDay(for: date, timezone: eastern), "2023-12-31")
    }
}
