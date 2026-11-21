func productExceptSelf(_ nums: [Int]) -> [Int] {
    var answer = [Int](repeating: 1, count: nums.count)
    for i in 1..<nums.count {
        answer[i] = answer[i - 1] * nums[i - 1]
    }
    var right = 1
    for i in stride(from: nums.count - 1, through: 0, by: -1) {
        answer[i] *= right
        right *= nums[i]
    }
    return answer
}
