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
}
