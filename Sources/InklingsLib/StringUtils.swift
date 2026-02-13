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
