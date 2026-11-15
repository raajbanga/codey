import SwiftUI

// The game layer's pieces (S41): XP rewards and the level hero on Play.

/// The top of Play (S41 mockup): level and XP toward the next one on a
/// slate card. Streak and today's goal live elsewhere (header, quests),
/// so this card says one thing.
///
///     Level 3                     320 / 500 XP
///     ████████████░░░░░░
///     180 XP to Level 4
struct LevelHero: View {
    let xp: Int
    @Environment(\.appHue) private var appHue
    private var hue: CodeyColor.TopicHue { appHue ?? .slate }

    private var level: Int { LevelCalculator.level(forXP: xp) }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Level \(level)")
                    .font(.codeyTitle.weight(.semibold))
                    .contentTransition(.numericText(value: Double(level)))
                Spacer(minLength: 0)
                Text("\(LevelCalculator.xpIntoLevel(xp)) / \(LevelCalculator.xpPerLevel) XP")
                    .font(.codeySubheadline.weight(.medium).monospacedDigit())
                    .contentTransition(.numericText(value: Double(xp)))
            }
            ProgressBar(value: LevelCalculator.progressFraction(xp), tint: hue.fill, height: 10, track: hue.fill.opacity(0.22))
            Text("\(LevelCalculator.xpToNextLevel(xp)) XP to Level \(level + 1)")
                .font(.codeySubheadline)
        }
        .foregroundStyle(hue.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(CodeySpacing.md)
        .background(hue.soft, in: .codey(CodeyRadius.lg))
        .codeyAnimation(CodeyMotion.snappy, value: xp)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(level), \(xp) XP, \(LevelCalculator.xpToNextLevel(xp)) to the next level")
        .accessibilityIdentifier("play.level")
    }
}

/// A reward that just landed, floating at the top of a quiz or study
/// session for a moment: "+5 XP", "Daily goal met +50 XP", "Level 4!".
struct XPToast: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let icon: String

    static func xp(_ amount: Int) -> XPToast { XPToast(title: "+\(amount) XP", icon: "star.fill") }
    static func bonus(_ bonus: XPRewards.Bonus) -> XPToast {
        XPToast(title: "\(bonus.title) +\(bonus.amount) XP", icon: "trophy.fill")
    }
    static func level(_ level: Int) -> XPToast { XPToast(title: "Level \(level)!", icon: "arrow.up.circle.fill") }
}

extension View {
    /// Shows `toast` at the top for 1.6 s, announced to VoiceOver.
    func xpToast(_ toast: Binding<XPToast?>) -> some View {
        modifier(XPToastModifier(toast: toast))
    }
}

private struct XPToastModifier: ViewModifier {
    @Binding var toast: XPToast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    Label(toast.title, icon: toast.icon)
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.xp)
                        .padding(.horizontal, CodeySpacing.lg)
                        .padding(.vertical, CodeySpacing.sm)
                        .background(CodeyColor.xpSoft, in: Capsule())
                        .overlay { Capsule().strokeBorder(CodeyColor.xp.opacity(0.25), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                        .padding(.top, CodeySpacing.xxl)
                        .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
                        .accessibilityAddTraits(.isStaticText)
                        .id(toast.id)
                        .allowsHitTesting(false)
                }
            }
            .task(id: toast?.id) {
                guard let toast else { return }
                UIAccessibility.post(notification: .announcement, argument: toast.title)
                try? await Task.sleep(for: .seconds(1.6))
                guard self.toast?.id == toast.id else { return }
                withCodeyAnimation(CodeyMotion.pop, reduceMotion: reduceMotion) { self.toast = nil }
            }
    }
}

// MARK: - Game tile

/// The one tile on Play and Decks (S41): topics, quests, exercises and
/// decks all share it, so every tile reads the same way.
///
///     ╭ ⋀          (Up next) ╮   ← icon, one status tag
///     │ Algorithms           │   ← title
///     │ [Easy] [+10 XP]      │   ← fact tags (CodeyChip): tier, what it pays
///     │ ━━━━━━──────         │   ← optional progress
///     │ [     ▶ Play       ] │   ← the action
///     ╰──────────────────────╯
///
/// `filled` puts the tile in its topic's pastel (text in its ink); off, it's
/// the plain note (text in primary / secondary). Callers wrap it in a Button
/// or NavigationLink; the action capsule is a label, not its own button.
struct GameTile<Status: View, Tags: View>: View {
    let icon: String
    let title: String
    var detail: String?
    let hue: CodeyColor.TopicHue
    var filled = true
    var progress: Double?
    var action: TileAction?
    /// Keeps the action's space empty for a button laid over it (Decks).
    var reservesAction = false
    @ViewBuilder var status: Status
    @ViewBuilder var tags: Tags

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            HStack(alignment: .center, spacing: CodeySpacing.sm) {
                Icon(icon, size: 26, relativeTo: .title2)
                    .foregroundStyle(filled ? hue.ink : hue.fill)
                Spacer(minLength: 0)
                status
            }
            Text(title)
                .font(.codeyHeadline)
                .foregroundStyle(filled ? hue.ink : CodeyColor.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, CodeySpacing.xxs)
            if let detail {
                Text(detail)
                    .font(.codeySubheadline)
                    .monospacedDigit()
                    .foregroundStyle(filled ? hue.ink : CodeyColor.textSecondary)
                    .lineLimit(3)
            }
            // Side by side when they fit; stacked rather than truncated
            // ("Me…") on a half-width tile.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CodeySpacing.xs) { tags }
                VStack(alignment: .leading, spacing: CodeySpacing.xs) { tags }
            }
            Spacer(minLength: CodeySpacing.sm)
            if let progress {
                ProgressBar(value: progress, tint: hue.fill, height: 8, track: hue.fill.opacity(0.22))
                    .padding(.bottom, CodeySpacing.xs)
            }
            if let action {
                TileActionLabel(action: action, hue: hue)
            } else if reservesAction {
                TileActionLabel(action: TileAction(""), hue: hue).hidden()
            }
        }
        .multilineTextAlignment(.leading)
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity, alignment: .topLeading)
        .codeyNote(fill: filled ? hue.soft : CodeyColor.surfaceRaised, edge: filled ? hue.soft : nil)
        // A pastel tile is the same light color in both modes (two-tone),
        // so its contents use light-mode colors: shared tags (tier, XP)
        // stay light chips on it instead of dark ones.
        .environment(\.colorScheme, filled ? .light : colorScheme)
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
    }

    @Environment(\.colorScheme) private var colorScheme
}

extension GameTile where Tags == EmptyView {
    init(icon: String, title: String, detail: String? = nil, hue: CodeyColor.TopicHue, filled: Bool = true,
         progress: Double? = nil, action: TileAction? = nil, reservesAction: Bool = false,
         @ViewBuilder status: () -> Status) {
        self.init(icon: icon, title: title, detail: detail, hue: hue, filled: filled, progress: progress,
                  action: action, reservesAction: reservesAction, status: status, tags: { EmptyView() })
    }
}

extension GameTile where Status == EmptyView {
    init(icon: String, title: String, detail: String? = nil, hue: CodeyColor.TopicHue, filled: Bool = true,
         progress: Double? = nil, action: TileAction? = nil, reservesAction: Bool = false,
         @ViewBuilder tags: () -> Tags) {
        self.init(icon: icon, title: title, detail: detail, hue: hue, filled: filled, progress: progress,
                  action: action, reservesAction: reservesAction, status: { EmptyView() }, tags: tags)
    }
}

extension GameTile where Status == EmptyView, Tags == EmptyView {
    init(icon: String, title: String, detail: String? = nil, hue: CodeyColor.TopicHue, filled: Bool = true,
         progress: Double? = nil, action: TileAction? = nil, reservesAction: Bool = false) {
        self.init(icon: icon, title: title, detail: detail, hue: hue, filled: filled, progress: progress,
                  action: action, reservesAction: reservesAction, status: { EmptyView() }, tags: { EmptyView() })
    }
}

/// What a tile's capsule says: "Play", "Study", "Solve".
struct TileAction {
    let title: String
    var icon: String?
    /// The topic fill with white text; off, a quiet neutral capsule for a
    /// tile that isn't the next thing to do.
    var prominent = true

    init(_ title: String, icon: String? = "play", prominent: Bool = true) {
        self.title = title
        self.icon = icon
        self.prominent = prominent
    }
}

/// The capsule at the bottom of a GameTile. Also the label of the Study
/// button Decks lays over a tile, so both are the same size.
struct TileActionLabel: View {
    let action: TileAction
    let hue: CodeyColor.TopicHue

    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 48

    var body: some View {
        HStack(spacing: CodeySpacing.xs) {
            if let icon = action.icon {
                // Same icon size as CodeyButton: about 0.8 of the text, as in a tag.
                Icon(icon, size: 18, relativeTo: .title2)
            }
            Text(action.title)
                .font(.codeyHeadline)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(action.prominent ? .white : CodeyColor.textPrimary)
        .padding(.horizontal, CodeySpacing.sm)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(action.prominent ? hue.fill : CodeyColor.fillNeutral, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.title)
    }
}

/// Dims on press, nothing else (a tile-sized button).
struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}
