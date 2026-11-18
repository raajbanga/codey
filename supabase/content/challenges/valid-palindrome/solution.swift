func isPalindrome(_ s: String) -> Bool {
    let chars = Array(s.lowercased()).filter { $0.isLetter || $0.isNumber }
    var i = 0, j = chars.count - 1
    while i < j {
        if chars[i] != chars[j] { return false }
        i += 1
        j -= 1
    }
    return true
}
