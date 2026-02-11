import XCTest
@testable import InklingsLib

final class WordCountTests: XCTestCase {
    
    func testEmptyString() {
        XCTAssertEqual(countWords(""), 0)
    }
    
    func testSingleWord() {
        XCTAssertEqual(countWords("hello"), 1)
    }
    
    func testMultipleWords() {
        XCTAssertEqual(countWords("hello world"), 2)
    }
    
    func testExtraWhitespace() {
        XCTAssertEqual(countWords("  hello   world  "), 2)
    }
    
    func testNewlines() {
        XCTAssertEqual(countWords("hello\nworld\n\nfoo"), 3)
    }
    
    func testTabsAndMixedWhitespace() {
        XCTAssertEqual(countWords("hello\t\tworld  foo\nbar"), 4)
    }
}
