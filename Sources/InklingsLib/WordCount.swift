import Foundation

public func countWords(_ text: String) -> Int {
    let words = text.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
    return words.count
}
