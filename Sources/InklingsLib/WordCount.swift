import Foundation

public func countWords(_ text: String) -> Int {
    let words = text.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
    return words.count
}

/// Get the "writing day" for a given date in user's timezone.
/// Days reset at 3 AM, so 2:30 AM Tuesday counts as Monday.
/// Returns format: "yyyy-MM-dd"
public func getWritingDay(for date: Date, timezone: TimeZone) -> String {
    // Subtract 3 hours to shift the day boundary to 3 AM
    let adjustedDate = date.addingTimeInterval(-3 * 60 * 60)
    
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timezone
    
    let year = calendar.component(.year, from: adjustedDate)
    let month = calendar.component(.month, from: adjustedDate)
    let day = calendar.component(.day, from: adjustedDate)
    
    return String(format: "%04d-%02d-%02d", year, month, day)
}

/// Determines if a streak should continue based on current state.
/// Returns true if streak continues, false if it should reset to 1.
///
/// Streak continues if ANY of:
/// - lastGoalMetDate == today (already counted today)
/// - lastGoalMetDate == yesterday (met goal yesterday)
/// - streakFrozen == true (frozen protects gaps)
/// - unfrozenAt == today (grace period after unfreeze)
public func shouldStreakContinue(
    lastGoalMetDate: String?,
    today: String,
    yesterday: String,
    streakFrozen: Bool,
    unfrozenAt: String?
) -> Bool {
    // Already met goal today
    if lastGoalMetDate == today {
        return true
    }
    
    // Met goal yesterday - streak continues
    if lastGoalMetDate == yesterday {
        return true
    }
    
    // Streak is frozen - gaps don't break it
    if streakFrozen {
        return true
    }
    
    // Just unfroze today - grace period
    if unfrozenAt == today {
        return true
    }
    
    // No conditions met - streak resets
    return false
}
