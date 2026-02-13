import Foundation

public struct Comment {
    public let id: Int
    public let userName: String
    public let commentText: String
    public let selectedText: String?
    public let startOffset: Int?
    public let endOffset: Int?
    public let fontColor: String
    public let fontName: String
    
    public init(id: Int, userName: String, commentText: String, selectedText: String?, startOffset: Int?, endOffset: Int?, fontColor: String, fontName: String) {
        self.id = id
        self.userName = userName
        self.commentText = commentText
        self.selectedText = selectedText
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.fontColor = fontColor
        self.fontName = fontName
    }
}

public func generateID(from title: String) -> String {
    // Convert to lowercase and replace spaces/special chars with dashes
    let allowed = CharacterSet.alphanumerics
    var id = title.lowercased()
        .components(separatedBy: allowed.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: "-")
    
    if id.isEmpty {
        id = "untitled"
    }
    
    return id
}

public func formatBodyInHTML(_ body: String) -> String {
    let paragraphs = body.components(separatedBy: "\n")
    let formattedParagraphs = paragraphs.map { p in
        return "<p class='notebook'>\(p)</p>"
    }
    return formattedParagraphs.joined()
}
