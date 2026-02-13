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

final class FormatBodyInHTMLTests: XCTestCase {
    
    func testSingleParagraph() {
        XCTAssertEqual(
            formatBodyInHTML("Hello world"),
            "<p class='notebook'>Hello world</p>"
        )
    }
    
    func testMultipleParagraphs() {
        XCTAssertEqual(
            formatBodyInHTML("First\nSecond\nThird"),
            "<p class='notebook'>First</p><p class='notebook'>Second</p><p class='notebook'>Third</p>"
        )
    }
    
    func testEmptyString() {
        XCTAssertEqual(
            formatBodyInHTML(""),
            "<p class='notebook'></p>"
        )
    }
    
    func testEmptyLines() {
        XCTAssertEqual(
            formatBodyInHTML("First\n\nThird"),
            "<p class='notebook'>First</p><p class='notebook'></p><p class='notebook'>Third</p>"
        )
    }
    
    func testSpecialCharacters() {
        // TODO: This function does NOT escape HTML - potential XSS vulnerability
        // Input containing <script> tags passes through unchanged
        XCTAssertEqual(
            formatBodyInHTML("<script>alert('xss')</script>"),
            "<p class='notebook'><script>alert('xss')</script></p>"
        )
    }
}

final class RenderBodyWithInlineCommentsTests: XCTestCase {
    
    func testNoComments() {
        let result = renderBodyWithInlineComments("Hello world", comments: [])
        XCTAssertEqual(result, "<p class='notebook'>Hello world</p>")
    }
    
    func testCommentWithoutSelectedText() {
        let comment = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Nice!",
            selectedText: nil,
            startOffset: nil,
            endOffset: nil,
            fontColor: "#333",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment])
        // Should return just formatted body since no selectedText
        XCTAssertEqual(result, "<p class='notebook'>Hello world</p>")
    }
    
    func testCommentWithEmptySelectedText() {
        let comment = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Nice!",
            selectedText: "",
            startOffset: nil,
            endOffset: nil,
            fontColor: "#333",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment])
        XCTAssertEqual(result, "<p class='notebook'>Hello world</p>")
    }
    
    func testSingleComment() {
        let comment = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Great word!",
            selectedText: "Hello",
            startOffset: 0,
            endOffset: 5,
            fontColor: "#ff0000",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment])
        
        let expected = "<p class='notebook'><span class=\"comment-anchor\"><span class=\"commented-text\" data-comment-ids=\"1\" style=\"background: linear-gradient(#ff0000, #ff0000) 0 1.15em / 100% 2px no-repeat; padding-bottom: 4px;\">Hello</span><span class=\"inline-comment\" data-comment-id=\"1\" style=\"color: #ff0000; font-family: Handwriting;\">Great word! &mdash;Alice</span></span> world</p>"
        
        XCTAssertEqual(result, expected)
    }
    
    func testCommentSelectedTextNotFound() {
        let comment = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Nice!",
            selectedText: "Goodbye",
            startOffset: nil,
            endOffset: nil,
            fontColor: "#333",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment])
        // Selected text not in body, should return just formatted body
        XCTAssertEqual(result, "<p class='notebook'>Hello world</p>")
    }
    
    func testCustomFontFamily() {
        let comment = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Nice!",
            selectedText: "Hello",
            startOffset: 0,
            endOffset: 5,
            fontColor: "#333",
            fontName: "custom-myfont"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment])
        // Custom fonts should be quoted
        XCTAssertTrue(result.contains("font-family: 'custom-myfont'"))
    }
    
    func testStandardFontFamily() {
        let comment = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Nice!",
            selectedText: "Hello",
            startOffset: 0,
            endOffset: 5,
            fontColor: "#333",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment])
        // Standard fonts should not be quoted
        XCTAssertTrue(result.contains("font-family: Handwriting;"))
    }

    func testCommentOnRepeatedWord() {
        // "Hello, hello, hello world!" - we want to comment on the 3rd "hello" (positions 14-19)
        let comment = Comment(
            id: 1,
            userName: "Editor",
            commentText: "Too many repetitions",
            selectedText: "hello",
            startOffset: 14,
            endOffset: 19,
            fontColor: "#0000ff",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello, hello, hello world!", comments: [comment])
        
        // The comment should be on the 3rd "hello", not the 1st or 2nd
        // Expected: "<p class='notebook'>Hello, hello, <span...>hello</span> world!</p>"
        XCTAssertTrue(result.contains("Hello, hello, <span"), "Comment should be on 3rd 'hello', not earlier ones")
    }
    
    func testTwoOverlappingComments() {
        // "The quick brown fox" with comments on "quick brown" and "brown fox"
        let comment1 = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Nice phrase",
            selectedText: "quick brown",
            startOffset: 4,
            endOffset: 15,
            fontColor: "#ff0000",
            fontName: "Handwriting"
        )
        let comment2 = Comment(
            id: 2,
            userName: "Bob",
            commentText: "Classic combo",
            selectedText: "brown fox",
            startOffset: 10,
            endOffset: 19,
            fontColor: "#00ff00",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("The quick brown fox", comments: [comment1, comment2])
        
        // Both comments should appear
        XCTAssertTrue(result.contains("Nice phrase"), "First comment text should appear")
        XCTAssertTrue(result.contains("Alice"), "First commenter should appear")
        XCTAssertTrue(result.contains("Classic combo"), "Second comment text should appear")
        XCTAssertTrue(result.contains("Bob"), "Second commenter should appear")
        
        // "brown" should be in the overlap (both comment IDs)
        XCTAssertTrue(result.contains("data-comment-ids=\"1,2\"") || result.contains("data-comment-ids=\"2,1\""), 
            "Overlapping segment should have both comment IDs")
        XCTAssertTrue(result.contains("data-comment-ids=\"1\""), 
            "Non-overlapping segment should have alice's ID")
        XCTAssertTrue(result.contains("data-comment-ids=\"2\""), 
            "Non-overlapping segment should have bob's ID")
    }
    
    func testNestedComments() {
        // "Hello world" with comments on "Hello world" and "world"
        let comment1 = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Outer comment",
            selectedText: "Hello world",
            startOffset: 0,
            endOffset: 11,
            fontColor: "#ff0000",
            fontName: "Handwriting"
        )
        let comment2 = Comment(
            id: 2,
            userName: "Bob",
            commentText: "Inner comment",
            selectedText: "world",
            startOffset: 6,
            endOffset: 11,
            fontColor: "#00ff00",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment1, comment2])
        
        // Both comments should appear
        XCTAssertTrue(result.contains("Outer comment"), "Outer comment should appear")
        XCTAssertTrue(result.contains("Inner comment"), "Inner comment should appear")
        
        // "world" should have both comment IDs (nested)
        XCTAssertTrue(result.contains("data-comment-ids=\"1,2\"") || result.contains("data-comment-ids=\"2,1\""),
            "Nested segment should have both comment IDs")
        XCTAssertTrue(result.contains("data-comment-ids=\"1\""), 
            "Non-nested segment should only have alice's ID")
        XCTAssertFalse(result.contains("data-comment-ids=\"2\""), 
            "Bob's ID should not appear alone anywhere")

    }
    
    func testAdjacentNonOverlappingComments() {
        // "Hello world" with comments on "Hello" and "world" (no overlap)
        let comment1 = Comment(
            id: 1,
            userName: "Alice",
            commentText: "Greeting",
            selectedText: "Hello",
            startOffset: 0,
            endOffset: 5,
            fontColor: "#ff0000",
            fontName: "Handwriting"
        )
        let comment2 = Comment(
            id: 2,
            userName: "Bob",
            commentText: "Planet",
            selectedText: "world",
            startOffset: 6,
            endOffset: 11,
            fontColor: "#00ff00",
            fontName: "Handwriting"
        )
        let result = renderBodyWithInlineComments("Hello world", comments: [comment1, comment2])
        
        // Both comments should appear
        XCTAssertTrue(result.contains("Greeting"), "First comment should appear")
        XCTAssertTrue(result.contains("Planet"), "Second comment should appear")
        
        // Each segment should have only one comment ID
        XCTAssertTrue(result.contains("data-comment-ids=\"1\""), "First segment should have only comment 1")
        XCTAssertTrue(result.contains("data-comment-ids=\"2\""), "Second segment should have only comment 2")
    }
}
