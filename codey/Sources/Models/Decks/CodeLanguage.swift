/// Languages a card's code snippet can use (FR-07, FR-08).
enum CodeLanguage: String, Codable, CaseIterable, Identifiable {
    case swift
    case python
    case java
    case cpp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .python: "Python"
        case .java: "Java"
        case .cpp: "C++"
        }
    }

    /// Info string for a fenced markdown block (also the Prism grammar key).
    var fenceTag: String { rawValue }
}
