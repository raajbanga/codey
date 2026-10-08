/// Where a deck came from. Starter decks are bundled, read-only, and never sync.
enum DeckOrigin: String, Codable, CaseIterable {
    case starter
    case user
}
