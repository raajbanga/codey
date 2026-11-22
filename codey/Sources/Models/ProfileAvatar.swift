/// The avatars a learner can pick (FR-04, Q4): an SF Symbol and a color, so
/// there are no image assets to sync. The stored value is the symbol name,
/// optionally followed by "@" and a color ("cat@teal"); without a color it
/// is slate. The server's profiles.avatar_id CHECK lists the same symbols
/// and colors (a test keeps them equal).
enum ProfileAvatar {
    /// The first twelve are the original set (stored names kept as they
    /// were); the rest were added with colors (S42).
    static let symbols = [
        "person.fill", "star.fill", "bolt.fill", "leaf.fill",
        "flame.fill", "moon.fill", "sun.max.fill", "cloud.fill",
        "hare.fill", "tortoise.fill", "brain.head.profile", "terminal.fill",
        "cat", "dog", "bird", "fish",
        "graduationcap", "book", "pencil", "lightbulb",
        "puzzlepiece", "gamecontroller", "atom", "cpu",
        "keyboard", "globe.americas", "music.note", "paintpalette",
        "trophy", "heart", "mountain.2", "sparkles",
    ]

    /// The avatar colors: the topic hues, so an avatar sits with the tiles.
    enum Color: String, CaseIterable, Identifiable {
        case slate, teal, sky, olive, sand, coral, rose, gold, green, indigo, violet, plum

        var id: String { rawValue }

        var hue: CodeyColor.TopicHue {
            switch self {
            case .slate: .slate
            case .teal: .teal
            case .sky: .sky
            case .olive: .olive
            case .sand: .sand
            case .coral: .coral
            case .rose: .rose
            case .gold: .gold
            case .green: .green
            case .indigo: .indigo
            case .violet: .violet
            case .plum: .plum
            }
        }

        var label: String { rawValue.capitalized }
    }

    /// Shown when no avatar is picked (or an unknown one arrives).
    static let fallback = "person.fill"

    /// The picked symbol, or the fallback.
    static func symbol(for avatarId: String?) -> String {
        parse(avatarId)?.symbol ?? fallback
    }

    /// The picked color, slate by default.
    static func color(for avatarId: String?) -> Color {
        parse(avatarId)?.color ?? .slate
    }

    /// The outline glyph drawn for a stored symbol: one line style for every
    /// avatar, like the app's own icons.
    static func glyph(for symbol: String) -> String {
        symbol.hasSuffix(".fill") ? String(symbol.dropLast(5)) : symbol
    }

    static func id(symbol: String, color: Color) -> String {
        color == .slate ? symbol : "\(symbol)@\(color.rawValue)"
    }

    /// "cat@teal" → (cat, teal). Nil for nil or anything outside the sets.
    static func parse(_ avatarId: String?) -> (symbol: String, color: Color)? {
        guard let avatarId else { return nil }
        let parts = avatarId.split(separator: "@", maxSplits: 1).map(String.init)
        guard let symbol = parts.first, symbols.contains(symbol) else { return nil }
        if parts.count == 1 { return (symbol, .slate) }
        guard let color = Color(rawValue: parts[1]) else { return nil }
        return (symbol, color)
    }
}
