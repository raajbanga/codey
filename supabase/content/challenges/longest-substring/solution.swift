func lengthOfLongestSubstring(_ s: String) -> Int {
    var last: [Character: Int] = [:]
    var left = 0, best = 0
    for (right, c) in s.enumerated() {
        if let seen = last[c], seen >= left {
            left = seen + 1
        }
        last[c] = right
        best = max(best, right - left + 1)
    }
    return best
}
