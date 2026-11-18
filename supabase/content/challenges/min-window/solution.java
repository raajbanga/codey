class Solution {
    public String minWindow(String s, String t) {
        int[] need = new int[128];
        for (char c : t.toCharArray()) need[c]++;
        int missing = t.length(), left = 0, bestStart = 0, bestLen = Integer.MAX_VALUE;
        for (int right = 0; right < s.length(); right++) {
            char c = s.charAt(right);
            if (need[c] > 0) missing--;
            need[c]--;
            if (missing == 0) {
                while (need[s.charAt(left)] < 0) need[s.charAt(left++)]++;
                if (right + 1 - left < bestLen) { bestLen = right + 1 - left; bestStart = left; }
                need[s.charAt(left++)]++;
                missing++;
            }
        }
        return bestLen == Integer.MAX_VALUE ? "" : s.substring(bestStart, bestStart + bestLen);
    }
}
