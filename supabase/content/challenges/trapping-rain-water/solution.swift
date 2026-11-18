func trap(_ height: [Int]) -> Int {
    var left = 0, right = height.count - 1
    var leftMax = 0, rightMax = 0, water = 0
    while left < right {
        if height[left] < height[right] {
            leftMax = max(leftMax, height[left])
            water += leftMax - height[left]
            left += 1
        } else {
            rightMax = max(rightMax, height[right])
            water += rightMax - height[right]
            right -= 1
        }
    }
    return water
}
