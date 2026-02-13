import Foundation

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
