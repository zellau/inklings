import XCTest
@testable import InklingsLib

final class StreakTests: XCTestCase {
    
    let today = "2024-01-15"
    let yesterday = "2024-01-14"
    
    func testAlreadyMetToday() {
        // If we already met the goal today, streak continues
        let result = shouldStreakContinue(
            lastGoalMetDate: today,
            today: today,
            yesterday: yesterday,
            streakFrozen: false,
            unfrozenAt: nil
        )
        XCTAssertTrue(result)
    }
    
    func testMetYesterday() {
        // Met goal yesterday, streak continues
        let result = shouldStreakContinue(
            lastGoalMetDate: yesterday,
            today: today,
            yesterday: yesterday,
            streakFrozen: false,
            unfrozenAt: nil
        )
        XCTAssertTrue(result)
    }
    
    func testMissedYesterdayNotFrozen() {
        // Missed yesterday and not frozen - streak resets
        let result = shouldStreakContinue(
            lastGoalMetDate: "2024-01-13",  // two days ago
            today: today,
            yesterday: yesterday,
            streakFrozen: false,
            unfrozenAt: nil
        )
        XCTAssertFalse(result)
    }
    
    func testMissedYesterdayButFrozen() {
        // Missed yesterday but frozen - streak continues
        let result = shouldStreakContinue(
            lastGoalMetDate: "2024-01-13",  // two days ago
            today: today,
            yesterday: yesterday,
            streakFrozen: true,
            unfrozenAt: nil
        )
        XCTAssertTrue(result)
    }
    
    func testUnfrozeToday() {
        // Unfroze today - grace period, streak continues
        let result = shouldStreakContinue(
            lastGoalMetDate: "2024-01-10",  // days ago
            today: today,
            yesterday: yesterday,
            streakFrozen: false,
            unfrozenAt: today
        )
        XCTAssertTrue(result)
    }
    
    func testUnfrozeYesterday() {
        // Unfroze yesterday, didn't write - no grace period today
        let result = shouldStreakContinue(
            lastGoalMetDate: "2024-01-10",  // days ago
            today: today,
            yesterday: yesterday,
            streakFrozen: false,
            unfrozenAt: yesterday
        )
        XCTAssertFalse(result)
    }
    
    func testNeverMetGoal() {
        // Never met a goal before
        let result = shouldStreakContinue(
            lastGoalMetDate: nil,
            today: today,
            yesterday: yesterday,
            streakFrozen: false,
            unfrozenAt: nil
        )
        XCTAssertFalse(result)
    }
    
    func testNeverMetGoalButFrozen() {
        // Never met goal but frozen (edge case - shouldn't really happen)
        let result = shouldStreakContinue(
            lastGoalMetDate: nil,
            today: today,
            yesterday: yesterday,
            streakFrozen: true,
            unfrozenAt: nil
        )
        XCTAssertTrue(result)  // Frozen still protects
    }
}
