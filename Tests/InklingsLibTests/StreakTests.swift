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
