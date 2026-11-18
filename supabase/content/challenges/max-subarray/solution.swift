func maxSubArray(_ nums: [Int]) -> Int {
    var best = nums[0], current = nums[0]
    for x in nums.dropFirst() {
        current = max(x, current + x)
        best = max(best, current)
    }
    return best
}
