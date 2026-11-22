import java.util.*;

class Solution {
    public String[][] groupAnagrams(String[] strs) {
        Map<String, List<String>> groups = new LinkedHashMap<>();
        for (String word : strs) {
            char[] key = word.toCharArray();
            Arrays.sort(key);
            groups.computeIfAbsent(new String(key), k -> new ArrayList<>()).add(word);
        }
        String[][] answer = new String[groups.size()][];
        int i = 0;
        for (List<String> group : groups.values()) answer[i++] = group.toArray(new String[0]);
        return answer;
    }
}
