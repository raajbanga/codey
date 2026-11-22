func minWindow(_ s: String, _ t: String) -> String {
    let chars = Array(s)
    var need: [Character: Int] = [:]
    for c in t { need[c, default: 0] += 1 }
    var missing = t.count
    var left = 0
    var best: (Int, Int)? = nil
    for right in 0..<chars.count {
        let c = chars[right]
        if need[c, default: 0] > 0 { missing -= 1 }
        need[c, default: 0] -= 1
        if missing == 0 {
            while need[chars[left]]! < 0 {
                need[chars[left]]! += 1
                left += 1
            }
            if best == nil || right + 1 - left < best!.1 - best!.0 {
                best = (left, right + 1)
            }
            need[chars[left]]! += 1
            missing += 1
            left += 1
        }
    }
    guard let (start, end) = best else { return "" }
    return String(chars[start..<end])
}
