func groupAnagrams(_ strs: [String]) -> [[String]] {
    var groups: [String: [String]] = [:]
    for word in strs {
        groups[String(word.sorted()), default: []].append(word)
    }
    return Array(groups.values)
}
