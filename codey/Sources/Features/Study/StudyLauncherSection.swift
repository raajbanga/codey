import SwiftData
import SwiftUI

/// Deck screen's "Study" block: Continue / Start over, and a tier picker
/// limited to unlocked tiers (FR-29). Starter decks show the lock state of
/// each tier (D9); user decks are never locked.
struct StudyLauncherSection: View {
    let deck: FlashcardDeck
    let start: (StudySessionViewModel.Start) -> Void

    @Query private var snapshots: [StudyProgressSnapshot]
    @Query private var profiles: [UserProfile]
    @State private var tierFilter: Difficulty?

    init(deck: FlashcardDeck, start: @escaping (StudySessionViewModel.Start) -> Void) {
        self.deck = deck
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
        Section {
            if deck.origin == .starter {
                TierChipRow(tiers: tiers)
            }

            if !taggedTiers.isEmpty {
                Picker("Cards", selection: $tierFilter) {
                    Text(deck.origin == .starter ? "Mixed (unlocked)" : "All tiers").tag(Difficulty?.none)
                    ForEach(taggedTiers.filter(unlocked.contains), id: \.self) { tier in
                        Label(tier.style.label, systemImage: tier.style.symbol).tag(Difficulty?.some(tier))
                    }
                }
                .pickerStyle(.menu)
                .tint(CodeyColor.brand)
            }

            if let snapshot {
                CodeyButton(
                    "Continue · \(snapshot.queue.displayPosition)/\(snapshot.queue.distinctTotal)",
                    systemImage: "play.fill",
                    fullWidth: true
                ) { start(.resume) }
                .accessibilityIdentifier("deck.continue")
                CodeyButton("Start Over", systemImage: "arrow.counterclockwise", kind: .secondary, fullWidth: true) {
                    start(.fresh(tierFilter: tierFilter))
                }
            } else {
                CodeyButton("Study", systemImage: "play.fill", fullWidth: true) {
                    start(.fresh(tierFilter: tierFilter))
                }
                .accessibilityIdentifier("deck.study")
            }
        } header: {
            Text("Study")
        } footer: {
            Text(footer)
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
