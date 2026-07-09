import XCTest
@testable import InklingsLib

final class StreakTests: XCTestCase {
    
    // MARK: - Basic Cases
    
    func testEmptyHistory() {
        let result = calculateStreak(history: [], today: "2024-03-30")
        XCTAssertEqual(result, 0)
    }
    
    func testSingleDayStreak() {
        let history = [StreakDay(date: "2024-03-30", goalMet: true)]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 1)
    }
    
    func testSingleDayGoalNotMet() {
        let history = [StreakDay(date: "2024-03-30", goalMet: false)]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 0)
    }
    
    func testThreeDayStreak() {
        let history = [
            StreakDay(date: "2024-03-30", goalMet: true),
            StreakDay(date: "2024-03-29", goalMet: true),
            StreakDay(date: "2024-03-28", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 3)
    }
    
    // MARK: - Streak Breaking
    
    func testGapBreaksStreak() {
        let history = [
            StreakDay(date: "2024-03-30", goalMet: true),
            StreakDay(date: "2024-03-28", goalMet: true)  // Gap on 29th
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 1)
    }
    
    func testGoalNotMetBreaksStreak() {
        let history = [
            StreakDay(date: "2024-03-30", goalMet: true),
            StreakDay(date: "2024-03-29", goalMet: false),
            StreakDay(date: "2024-03-28", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 1)
    }
    
    // MARK: - Today Edge Cases
    
    func testNoWritingToday() {
        let history = [
            StreakDay(date: "2024-03-29", goalMet: true),
            StreakDay(date: "2024-03-28", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        // No entry for today means streak is 0 (gap from today to 29th)
        XCTAssertEqual(result, 0)
    }
    
    func testLongStreak() {
        var history: [StreakDay] = []
        for i in 0..<100 {
            let date = previousDay(String(repeating: "", count: 0) + "2024-06-01", daysBack: i)
            history.append(StreakDay(date: date, goalMet: true))
        }
        let result = calculateStreak(history: history, today: "2024-06-01")
        XCTAssertEqual(result, 100)
    }
    
    // MARK: - Edge Cases
    
    func testFutureDateInHistory() {
        // Future dates should be skipped
        let history = [
            StreakDay(date: "2024-04-01", goalMet: true),  // Future
            StreakDay(date: "2024-03-30", goalMet: true),  // Today
            StreakDay(date: "2024-03-29", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 2)
    }
    
    func testStreakBrokenByMultiDayGap() {
        // 3-day gap should break streak
        let history = [
            StreakDay(date: "2024-03-30", goalMet: true),
            StreakDay(date: "2024-03-26", goalMet: true)  // 3-day gap
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 1)
    }
    
    func testWroteButDidntMeetGoalToday() {
        // Wrote today but didn't meet goal -> streak is 0
        let history = [
            StreakDay(date: "2024-03-30", goalMet: false),
            StreakDay(date: "2024-03-29", goalMet: true),
            StreakDay(date: "2024-03-28", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 0)
    }
    
    func testStreakContinuesFromYesterday() {
        // Haven't written today yet, but yesterday met goal
        // This returns 0 because there's a gap from today
        let history = [
            StreakDay(date: "2024-03-29", goalMet: true),
            StreakDay(date: "2024-03-28", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-03-30")
        XCTAssertEqual(result, 0)
    }
    
    func testMonthTransition() {
        // Streak across month boundary
        let history = [
            StreakDay(date: "2024-04-02", goalMet: true),
            StreakDay(date: "2024-04-01", goalMet: true),
            StreakDay(date: "2024-03-31", goalMet: true),
            StreakDay(date: "2024-03-30", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-04-02")
        XCTAssertEqual(result, 4)
    }
    
    func testYearTransition() {
        // Streak across year boundary
        let history = [
            StreakDay(date: "2024-01-02", goalMet: true),
            StreakDay(date: "2024-01-01", goalMet: true),
            StreakDay(date: "2023-12-31", goalMet: true),
            StreakDay(date: "2023-12-30", goalMet: true)
        ]
        let result = calculateStreak(history: history, today: "2024-01-02")
        XCTAssertEqual(result, 4)
    }
    
    // MARK: - Helper Function Tests
    
    func testPreviousDay() {
        XCTAssertEqual(previousDay("2024-03-30"), "2024-03-29")
        XCTAssertEqual(previousDay("2024-03-01"), "2024-02-29")  // Leap year
        XCTAssertEqual(previousDay("2024-01-01"), "2023-12-31")
    }
    
    func testDaysBetween() {
        // Adjacent days = 0 gap
        XCTAssertEqual(daysBetween(from: "2024-03-29", to: "2024-03-30"), 0)
        // One day gap
        XCTAssertEqual(daysBetween(from: "2024-03-28", to: "2024-03-30"), 1)
        // Two day gap
        XCTAssertEqual(daysBetween(from: "2024-03-27", to: "2024-03-30"), 2)
    }
}

// Helper for generating dates
func previousDay(_ dateString: String, daysBack: Int) -> String {
    var result = dateString
    for _ in 0..<daysBack {
        result = previousDay(result)
    }
    return result
}

final class UserTodayTests: XCTestCase {
    
    func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }
    
    func testDayStartMidnight_afternoon() {
        // Day starts at midnight, it's 3pm -> today
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 15)
        XCTAssertEqual(userToday(dayStartHour: 0, now: now), "2024-03-15")
    }
    
    func testDayStartMidnight_justAfter() {
        // Day starts at midnight, it's 1am -> today
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 1)
        XCTAssertEqual(userToday(dayStartHour: 0, now: now), "2024-03-15")
    }
    
    func testDayStart3am_at2am() {
        // Day starts at 3am, it's 2am -> still yesterday
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 2)
        XCTAssertEqual(userToday(dayStartHour: 3, now: now), "2024-03-14")
    }
    
    func testDayStart3am_at3am() {
        // Day starts at 3am, it's 3am -> today
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 3)
        XCTAssertEqual(userToday(dayStartHour: 3, now: now), "2024-03-15")
    }
    
    func testDayStart3am_at4am() {
        // Day starts at 3am, it's 4am -> today
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 4)
        XCTAssertEqual(userToday(dayStartHour: 3, now: now), "2024-03-15")
    }
    
    func testDayStart3am_yearBoundary() {
        // Day starts at 3am, it's 2am on Jan 1 -> still Dec 31 of previous year
        let now = makeDate(year: 2024, month: 1, day: 1, hour: 2)
        XCTAssertEqual(userToday(dayStartHour: 3, now: now), "2023-12-31")
    }
    
    func testDayStartMidnight_at23() {
        // Day starts at midnight, it's 11pm -> today (not tomorrow)
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 23)
        XCTAssertEqual(userToday(dayStartHour: 0, now: now), "2024-03-15")
    }
    
    func testDayStart4am_atMidnight() {
        // Day starts at 4am, it's midnight -> still yesterday
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 0)
        XCTAssertEqual(userToday(dayStartHour: 4, now: now), "2024-03-14")
    }
    
    func testDayStart23_at22() {
        // Edge case: day starts at 11pm, it's 10pm -> still yesterday
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 22)
        XCTAssertEqual(userToday(dayStartHour: 23, now: now), "2024-03-14")
    }
    
    func testDayStart23_at23() {
        // Edge case: day starts at 11pm, it's 11pm -> today
        let now = makeDate(year: 2024, month: 3, day: 15, hour: 23)
        XCTAssertEqual(userToday(dayStartHour: 23, now: now), "2024-03-15")
    }
    
    func testLeapYearTransition() {
        // Feb 29 2024 at 2am with day start at 3am -> Feb 28
        let now = makeDate(year: 2024, month: 2, day: 29, hour: 2)
        XCTAssertEqual(userToday(dayStartHour: 3, now: now), "2024-02-28")
    }
    
    func testMonthBoundary() {
        // April 1 at 2am with day start at 3am -> March 31
        let now = makeDate(year: 2024, month: 4, day: 1, hour: 2)
        XCTAssertEqual(userToday(dayStartHour: 3, now: now), "2024-03-31")
    }
}

final class WordCountTests: XCTestCase {
    
    func testCountWordsSimple() {
        XCTAssertEqual(countWords("hello world"), 2)
    }
    
    func testCountWordsEmpty() {
        XCTAssertEqual(countWords(""), 0)
    }
    
    func testCountWordsMultipleSpaces() {
        XCTAssertEqual(countWords("hello   world"), 2)
    }
    
    func testCountWordsNewlines() {
        XCTAssertEqual(countWords("hello\nworld\nfoo"), 3)
    }
    
    func testCountWordsMixedWhitespace() {
        XCTAssertEqual(countWords("hello\t\n  world"), 2)
    }
    
    func testCountWordsOnlyWhitespace() {
        XCTAssertEqual(countWords("   \n\t  "), 0)
    }
    
    func testCountWordsParagraphs() {
        let text = """
        This is paragraph one.
        
        This is paragraph two with more words.
        """
        XCTAssertEqual(countWords(text), 11)
    }
    
    func testCountWordsPunctuation() {
        // Punctuation attached to words doesn't split them
        XCTAssertEqual(countWords("Hello, world!"), 2)
        XCTAssertEqual(countWords("Wait... what?"), 2)
    }
    
    func testCountWordsContractions() {
        // Contractions count as one word
        XCTAssertEqual(countWords("don't can't won't"), 3)
    }
    
    func testCountWordsHyphenated() {
        // Hyphenated words count as one word
        XCTAssertEqual(countWords("well-known self-aware"), 2)
    }
    
    func testCountWordsUnicode() {
        // Unicode letters are words too
        XCTAssertEqual(countWords("café naïve résumé"), 3)
        XCTAssertEqual(countWords("日本語 中文"), 2)
    }
    
    func testCountWordsEmoji() {
        // Emoji separated by spaces count as words
        XCTAssertEqual(countWords("🎉 hello 🌍"), 3)
    }
    
    func testCountWordsNumbers() {
        XCTAssertEqual(countWords("123 456 789"), 3)
        XCTAssertEqual(countWords("Chapter 1 Page 42"), 4)
    }
}

final class WordDeltaTests: XCTestCase {
    
    func testWordsAdded() {
        XCTAssertEqual(wordDelta(oldCount: 100, newCount: 150), 50)
    }
    
    func testWordsDeleted() {
        // Deletions don't subtract from streak
        XCTAssertEqual(wordDelta(oldCount: 100, newCount: 80), 0)
    }
    
    func testNoChange() {
        XCTAssertEqual(wordDelta(oldCount: 100, newCount: 100), 0)
    }
    
    func testFromZero() {
        XCTAssertEqual(wordDelta(oldCount: 0, newCount: 200), 200)
    }
    
    func testToZero() {
        // Clearing all text doesn't subtract
        XCTAssertEqual(wordDelta(oldCount: 500, newCount: 0), 0)
    }
}

final class HourLabelTests: XCTestCase {
    
    func testNow() {
        XCTAssertEqual(hourLabel(hour: 3, currentHour: 3), "3 AM (now)")
        XCTAssertEqual(hourLabel(hour: 0, currentHour: 0), "Midnight (now)")
        XCTAssertEqual(hourLabel(hour: 12, currentHour: 12), "Noon (now)")
    }
    
    func testInOneHour() {
        XCTAssertEqual(hourLabel(hour: 4, currentHour: 3), "4 AM (in 1 hour)")
        XCTAssertEqual(hourLabel(hour: 0, currentHour: 23), "Midnight (in 1 hour)")
    }
    
    func testMultipleHours() {
        XCTAssertEqual(hourLabel(hour: 8, currentHour: 3), "8 AM (in 5 hours)")
        XCTAssertEqual(hourLabel(hour: 15, currentHour: 10), "3 PM (in 5 hours)")
    }
    
    func testWrapAround() {
        // Current hour is 22 (10 PM), asking about 3 AM
        XCTAssertEqual(hourLabel(hour: 3, currentHour: 22), "3 AM (in 5 hours)")
    }
    
    func testMidnightAndNoon() {
        XCTAssertEqual(hourLabel(hour: 0, currentHour: 20), "Midnight (in 4 hours)")
        XCTAssertEqual(hourLabel(hour: 12, currentHour: 8), "Noon (in 4 hours)")
    }
    
    func testAllHourNames() {
        // Verify AM/PM naming
        XCTAssertEqual(hourLabel(hour: 1, currentHour: 1), "1 AM (now)")
        XCTAssertEqual(hourLabel(hour: 11, currentHour: 11), "11 AM (now)")
        XCTAssertEqual(hourLabel(hour: 13, currentHour: 13), "1 PM (now)")
        XCTAssertEqual(hourLabel(hour: 23, currentHour: 23), "11 PM (now)")
    }
    
    func testMaxHoursAway() {
        // 23 hours away (max possible)
        XCTAssertEqual(hourLabel(hour: 22, currentHour: 23), "10 PM (in 23 hours)")
    }
    
    func testWrapAroundMidnight() {
        // Going from PM to AM
        XCTAssertEqual(hourLabel(hour: 1, currentHour: 23), "1 AM (in 2 hours)")
        XCTAssertEqual(hourLabel(hour: 6, currentHour: 22), "6 AM (in 8 hours)")
    }
}
