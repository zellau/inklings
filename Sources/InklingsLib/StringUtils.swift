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

public func renderBodyWithInlineComments(_ bodyUnformatted: String, comments: [Comment]) -> String {
    let body = formatBodyInHTML(bodyUnformatted)
    
    // Filter to only comments with selected text
    let inlineComments = comments.filter { $0.selectedText != nil && !$0.selectedText!.isEmpty }
    
    if inlineComments.isEmpty {
        return body
    }
    
    // Find actual positions for each comment by searching for selectedText
    var commentRanges: [(start: Int, end: Int, id: Int, userName: String, commentText: String, fontColor: String, fontName: String)] = []
    
    for comment in inlineComments {
        guard let selectedText = comment.selectedText else { continue }
        // Find the selected text in the body
        if let range = body.range(of: selectedText) {
            let start = body.distance(from: body.startIndex, to: range.lowerBound)
            let end = body.distance(from: body.startIndex, to: range.upperBound)
            commentRanges.append((start: start, end: end, id: comment.id, userName: comment.userName, commentText: comment.commentText, fontColor: comment.fontColor, fontName: comment.fontName))
        }
    }
    
    if commentRanges.isEmpty {
        return body
    }
    
    // Find all unique boundary points
    var boundaries = Set<Int>()
    for cr in commentRanges {
        boundaries.insert(cr.start)
        boundaries.insert(cr.end)
    }
    let sortedBoundaries = boundaries.sorted()
    
    // For each comment, determine which "lane" (vertical offset) it should use
    // Only offset when there's actual overlap with another comment
    // Sort by start position, then by end position (longer ranges first)
    let sortedCommentRanges = commentRanges.sorted { 
        if $0.start != $1.start { return $0.start < $1.start }
        return $0.end > $1.end  // Longer ranges first when same start
    }
    
    // Assign lanes: each comment gets the lowest lane not used by an overlapping comment
    var commentLane: [Int: Int] = [:]  // commentID -> lane (0 = closest to text)
    
    for cr in sortedCommentRanges {
        // Find which lanes are already used by overlapping comments
        var usedLanes = Set<Int>()
        for other in sortedCommentRanges {
            if other.id == cr.id { continue }
            // Check if they overlap
            if other.start < cr.end && other.end > cr.start {
                if let lane = commentLane[other.id] {
                    usedLanes.insert(lane)
                }
            }
        }
        // Assign the lowest unused lane
        var lane = 0
        while usedLanes.contains(lane) {
            lane += 1
        }
        commentLane[cr.id] = lane
    }
    
    // Build segments - each segment is a range with potentially multiple overlapping comments
    var segments: [(start: Int, end: Int, commentIDs: [Int])] = []
    
    for i in 0..<(sortedBoundaries.count - 1) {
        let segStart = sortedBoundaries[i]
        let segEnd = sortedBoundaries[i + 1]
        
        // Find all comment IDs that cover this segment
        var coveringIDs: [Int] = []
        for cr in commentRanges {
            if cr.start <= segStart && cr.end >= segEnd {
                coveringIDs.append(cr.id)
            }
        }
        
        segments.append((start: segStart, end: segEnd, commentIDs: coveringIDs))
    }
    
    // Create a lookup for comment details by ID
    var commentByID: [Int: (id: Int, userName: String, commentText: String, fontColor: String, fontName: String)] = [:]
    for cr in commentRanges {
        commentByID[cr.id] = (id: cr.id, userName: cr.userName, commentText: cr.commentText, fontColor: cr.fontColor, fontName: cr.fontName)
    }
    
    // Build result by processing segments in order
    var result = ""
    var currentIndex = 0
    let bodyChars = Array(body)
    var shownCommentIDs = Set<Int>()  // Track which comments we've shown
    
    for segment in segments {
        // Add any text before this segment
        if currentIndex < segment.start {
            result += String(bodyChars[currentIndex..<segment.start])
        }
        currentIndex = segment.end
        
        let segmentText = String(bodyChars[segment.start..<segment.end])
        
        if segment.commentIDs.isEmpty {
            // No comments on this segment, just add the text
            result += segmentText
        } else {
            // Build underline styles using linear-gradient backgrounds
            // Position from top using em units for consistent alignment across segments
            var gradientStyles: [String] = []
            var maxLane = 0
            for commentID in segment.commentIDs {
                if let lane = commentLane[commentID], let comment = commentByID[commentID] {
                    // Position each underline at 1.15em + (lane * 0.18em) from top
                    // Lane 0 = closest to text, only offset if there's overlap
                    let emOffset = 1.15 + (Double(lane) * 0.18)
                    gradientStyles.append("linear-gradient(\(comment.fontColor), \(comment.fontColor)) 0 \(emOffset)em / 100% 2px no-repeat")
                    if lane > maxLane {
                        maxLane = lane
                    }
                }
            }
            let background = gradientStyles.joined(separator: ", ")
            // Ensure enough padding for all underlines in this segment
            let paddingBottom = 4 + (maxLane * 4)
            
            // Check which comments end at this segment (show their text here)
            var commentsToShow: [(id: Int, userName: String, commentText: String, fontColor: String, fontName: String)] = []
            for cr in commentRanges {
                if cr.end == segment.end && !shownCommentIDs.contains(cr.id) {
                    if let comment = commentByID[cr.id] {
                        commentsToShow.append(comment)
                    }
                    shownCommentIDs.insert(cr.id)
                }
            }
            
            // Build the HTML - add data-comment-ids to track which comments this segment belongs to
            let commentIDsAttr = segment.commentIDs.map { String($0) }.joined(separator: ",")
            result += "<span class=\"comment-anchor\">"
            result += "<span class=\"commented-text\" data-comment-ids=\"\(commentIDsAttr)\" style=\"background: \(background); padding-bottom: \(paddingBottom)px;\">\(segmentText)</span>"
            
            // Add comment bubbles for comments that end here
            for comment in commentsToShow {
                let fontFamily = comment.fontName.starts(with: "custom-") ? "'\(comment.fontName)'" : comment.fontName
                result += "<span class=\"inline-comment\" data-comment-id=\"\(comment.id)\" style=\"color: \(comment.fontColor); font-family: \(fontFamily);\">\(comment.commentText) &mdash;\(comment.userName)</span>"
            }
            
            result += "</span>"
        }
    }
    
    // Add remaining text after last segment
    if currentIndex < bodyChars.count {
        result += String(bodyChars[currentIndex...])
    }
    
    return result
}
