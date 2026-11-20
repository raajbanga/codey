from typing import List


def groupAnagrams(strs: List[str]) -> List[List[str]]:
    groups = {}
    for word in strs:
        groups.setdefault("".join(sorted(word)), []).append(word)
    return list(groups.values())
