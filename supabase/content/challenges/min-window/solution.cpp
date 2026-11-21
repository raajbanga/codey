class Solution {
public:
    string minWindow(string& s, string& t) {
        vector<int> need(128, 0);
        for (char c : t) need[c]++;
        int missing = t.size(), left = 0, bestStart = 0, bestLen = INT_MAX;
        for (int right = 0; right < (int)s.size(); right++) {
            char c = s[right];
            if (need[c] > 0) missing--;
            need[c]--;
            if (missing == 0) {
                while (need[s[left]] < 0) need[s[left++]]++;
                if (right + 1 - left < bestLen) { bestLen = right + 1 - left; bestStart = left; }
                need[s[left++]]++;
                missing++;
            }
        }
        return bestLen == INT_MAX ? "" : s.substr(bestStart, bestLen);
    }
};
