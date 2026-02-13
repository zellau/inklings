import XCTest
@testable import InklingsLib

final class StringUtilsTests: XCTestCase {
    
    func testGenerateID_basicTitle() {
        XCTAssertEqual(generateID(from: "Hello World"), "hello-world")
    }
    
    func testGenerateID_alreadyLowercase() {
        XCTAssertEqual(generateID(from: "my page"), "my-page")
    }
    
    func testGenerateID_specialCharacters() {
        XCTAssertEqual(generateID(from: "Hello, World!"), "hello-world")
    }
    
    func testGenerateID_multipleSpaces() {
        XCTAssertEqual(generateID(from: "hello   world"), "hello-world")
    }
    
    func testGenerateID_numbers() {
        XCTAssertEqual(generateID(from: "Chapter 1"), "chapter-1")
    }
    
    func testGenerateID_emptyString() {
        XCTAssertEqual(generateID(from: ""), "untitled")
    }
    
    func testGenerateID_onlySpecialChars() {
        XCTAssertEqual(generateID(from: "!!!"), "untitled")
    }
    
    func testGenerateID_unicodeCharacters() {
        // Note: CharacterSet.alphanumerics includes accented chars
        XCTAssertEqual(generateID(from: "Café résumé"), "café-résumé")
    }
    
    func testGenerateID_leadingTrailingSpaces() {
        XCTAssertEqual(generateID(from: "  hello world  "), "hello-world")
    }
}
