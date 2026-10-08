import Foundation

/// Toolbar actions for the prompt/answer markdown fields.
enum MarkdownFormat: CaseIterable {
    case bold, italic, code, bulletList

    var marker: String {
        switch self {
        case .bold: "**"
        case .italic: "_"
        case .code: "`"
        case .bulletList: "- "
        }
    }
}

/// Pure text transforms behind the formatting toolbar. Offsets are in
/// Characters, so they map 1:1 onto String.Index ranges in the editor.
enum MarkdownFormatting {
    struct Result: Equatable {
        let text: String
        /// New selection, as character offsets.
        let selection: Range<Int>
    }

    /// Applies (or, if already applied, removes) `format` around/over the
    /// selected range. An empty selection inserts an empty pair with the
    /// cursor between the markers.
    static func apply(_ format: MarkdownFormat, to text: String, selection: Range<Int>) -> Result {
        let chars = Array(text)
        let lower = min(max(selection.lowerBound, 0), chars.count)
        let upper = min(max(selection.upperBound, lower), chars.count)
        switch format {
        case .bulletList:
            return toggleBullets(chars, lower: lower, upper: upper)
        case .bold, .italic, .code:
            return toggleWrap(chars, marker: Array(format.marker), lower: lower, upper: upper)
        }
    }

    private static func toggleWrap(_ chars: [Character], marker: [Character], lower: Int, upper: Int) -> Result {
        let m = marker.count
        let before = lower >= m ? Array(chars[(lower - m)..<lower]) : []
        let after = upper + m <= chars.count ? Array(chars[upper..<(upper + m)]) : []
        if before == marker, after == marker {
            var result = chars
            result.removeSubrange(upper..<(upper + m))
            result.removeSubrange((lower - m)..<lower)
            return Result(text: String(result), selection: (lower - m)..<(upper - m))
        }
        var result = chars
        result.insert(contentsOf: marker, at: upper)
        result.insert(contentsOf: marker, at: lower)
        return Result(text: String(result), selection: (lower + m)..<(upper + m))
    }

    private static func toggleBullets(_ chars: [Character], lower: Int, upper: Int) -> Result {
        // Expand to whole lines.
        var start = lower
        while start > 0, chars[start - 1] != "\n" { start -= 1 }
        var end = upper
        while end < chars.count, chars[end] != "\n" { end += 1 }

        let block = String(chars[start..<end])
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let allBulleted = lines.allSatisfy { $0.hasPrefix("- ") }
        let newLines = lines.map { line in
            allBulleted ? String(line.dropFirst(2)) : "- " + line
        }
        let newBlock = newLines.joined(separator: "\n")
        let text = String(chars[..<start]) + newBlock + String(chars[end...])
        return Result(text: text, selection: start..<(start + newBlock.count))
    }
}
