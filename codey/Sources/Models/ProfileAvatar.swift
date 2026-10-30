/// The avatars a learner can pick (FR-04, Q4): SF Symbols, so there are no
/// image assets to sync. The stored value is the symbol name; the server's
/// profiles.avatar_id CHECK lists the same set (a test keeps them equal).
enum ProfileAvatar {
    static let symbols = [
        "person.fill", "star.fill", "bolt.fill", "leaf.fill",
        "flame.fill", "moon.fill", "sun.max.fill", "cloud.fill",
        "hare.fill", "tortoise.fill", "brain.head.profile", "terminal.fill",
    ]

    /// Shown when no avatar is picked (or an unknown one arrives).
    static let fallback = "person.crop.circle.fill"

    static func symbol(for avatarId: String?) -> String {
        guard let avatarId, symbols.contains(avatarId) else { return fallback }
        return avatarId
    }
}
