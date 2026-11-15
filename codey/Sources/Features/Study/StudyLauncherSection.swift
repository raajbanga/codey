import SwiftData
import SwiftUI

/// Deck screen's "Study" block: Continue / Start over, and a tier picker
/// limited to unlocked tiers (FR-29). Starter decks say what opens the next
/// locked tier (D9); user decks are never locked.
struct StudyLauncherSection: View {
    let deck: FlashcardDeck
    /// The deck's topic color for the Study button (S41).
    var hue: CodeyColor.TopicHue = .brand
    let start: (StudySessionViewModel.Start) -> Void

    @Query private var snapshots: [StudyProgressSnapshot]
    @Query private var profiles: [UserProfile]
    @State private var tierFilter: Difficulty?

    init(deck: FlashcardDeck, hue: CodeyColor.TopicHue = .brand, start: @escaping (StudySessionViewModel.Start) -> Void) {
        self.deck = deck
        self.hue = hue
        self.start = start
        let id = deck.id
        _snapshots = Query(filter: #Predicate<StudyProgressSnapshot> { $0.deckId == id })
    }

    private var profile: UserProfile? { profiles.first }
    private var snapshot: StudyProgressSnapshot? { snapshots.first }
    private var tiers: [TierAvailability] {
        TierGate.availability(tallies: TierGate.tallies(for: deck), xp: profile?.totalXP, level: profile?.level ?? 1)
    }
    private var unlocked: Set<Difficulty> {
        TierGate.unlockedTiers(for: deck, level: profile?.level ?? 1)
    }
    private var taggedTiers: [Difficulty] { StudyPool.taggedTiers(in: deck) }
    private var poolCount: Int {
        StudyPool.cards(in: deck, unlockedTiers: unlocked, tierFilter: tierFilter).count
    }

    var body: some View {
        NoteGroup("Study", footer: footer) {
            if !taggedTiers.isEmpty {
                // The same pills as quiz setup (S41): Mixed or one tier.
                ChoiceChips(
                    "Cards",
                    selection: $tierFilter,
                    options: [(Difficulty?.none, "Mixed")] + taggedTiers.filter(unlocked.contains).map { (Difficulty?.some($0), $0.style.label) },
                    fills: true
                )
                .accessibilityIdentifier("deck.tierFilter")
            }
            if deck.origin == .starter {
                TierLockNote(tiers: tiers)
            }

            if snapshot != nil {
                CodeyButton(
                    "Continue",
                    systemImage: "play",
                    kind: .hue(hue),
                    fullWidth: true
                ) { start(.resume) }
                .accessibilityIdentifier("deck.continue")
                CodeyButton("Start Over", systemImage: "arrow.counterclockwise", kind: .secondary, fullWidth: true) {
                    start(.fresh(tierFilter: tierFilter))
                }
            } else {
                CodeyButton("Study", systemImage: "play", kind: .hue(hue), fullWidth: true) {
                    start(.fresh(tierFilter: tierFilter))
                }
                .accessibilityIdentifier("deck.study")
            }
        }
        .onChange(of: unlocked) { _, open in
            if let tierFilter, !open.contains(tierFilter) { self.tierFilter = nil }
        }
    }

    private var footer: String {
        let count = poolCount
        if count == 0 {
            return deck.origin == .starter
                ? "Every unlocked card is mastered. Mastered starter cards retire."
                : "No cards to study."
        }
        let cards = count.counted("card")
        return deck.origin == .starter ? "\(cards) to study. Cards retire once mastered." : "\(cards) to study."
    }
}
