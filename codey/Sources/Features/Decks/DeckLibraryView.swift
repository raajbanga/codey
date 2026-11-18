import SwiftData
import SwiftUI

/// Decks tab root (FR-05/12/15, UC-01/03).
struct DeckLibraryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case mine = "Mine"
        case starter = "Starter"
        var id: String { rawValue }
    }

    /// Live decks, newest edit first. A typed static keeps the #Predicate
    /// out of the property-wrapper expression, which took ~400 ms to
    /// type-check inline (and again in every #Preview that builds this view).
    private static let liveDecks = FetchDescriptor<FlashcardDeck>(
        predicate: #Predicate { $0.deletedAt == nil },
        sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )

    @Query(liveDecks) private var decks: [FlashcardDeck]
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query private var profiles: [UserProfile]

    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool
    @State private var showHiddenStarters = false
    /// The New Deck builder (editing opens from Deck detail).
    @State private var isBuilding = false
    @State private var actionError: String?

    @Environment(BackendFacade.self) private var backend
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context

    var body: some View {
        let topicsByID = topics.keyed(by: \.id)
        let sections = deckSections(topicsByID: topicsByID)
        CodeyPage("Decks", isTabRoot: true) {
            headerActions
        } leading: {
            countBadge
        } hero: {
            hero
        } content: {
            if isSearching {
                PageSearchField(prompt: "Title or topic", text: $searchText, focus: $searchFocused)
                    .accessibilityIdentifier("decks.searchField")
            }
            ChoiceChips("Show", selection: $filter, fills: true)

            if decks.isEmpty {
                EmptyStateView(
                    systemImage: "rectangle.stack.badge.plus",
                    title: "Make your first deck",
                    message: "Write your own prompt/answer cards, with code if you like.",
                    actionTitle: "New Deck",
                    action: { isBuilding = true }
                )
                .padding(.top, CodeySpacing.xl)
            } else if sections.user.isEmpty && sections.starter.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                if filter != .starter, !sections.user.isEmpty {
                    section(filter == .all ? "My decks" : nil, decks: sections.user, topicsByID: topicsByID)
                }
                if filter != .mine, !sections.starter.isEmpty {
                    section(filter == .all ? "Starter decks" : nil, decks: sections.starter, topicsByID: topicsByID)
                }
                if filter == .mine, sections.user.isEmpty {
                    EmptyStateView(
                        systemImage: "rectangle.stack.badge.plus",
                        title: "No decks of your own yet",
                        message: "Your decks show up here.",
                        actionTitle: "New Deck",
                        action: { isBuilding = true }
                    )
                }
            }

            if filter != .mine, hasHiddenStarters {
                // Our button, not the system switch.
                CodeyButton(
                    showHiddenStarters ? "Hide Hidden Starter Decks" : "Show Hidden Starter Decks",
                    systemImage: showHiddenStarters ? "eye.slash" : "eye",
                    kind: .secondary,
                    fullWidth: true
                ) { showHiddenStarters.toggle() }
                .accessibilityIdentifier("decks.showHidden")
            }
        }
        .refreshable { await backend.syncPending() }
        .navigationDestination(for: DeckRoute.self) { route in
            if let deck = decks.first(where: { $0.id == route.id }) {
                DeckDetailView(deck: deck, topic: topicsByID[deck.topicId])
            }
        }
        .sheet(isPresented: $isBuilding) {
            DeckBuilderView(
                viewModel: DeckViewModel(
                    backend: backend,
                    knownTopicIds: Set(topics.map(\.id)),
                    defaultTopicId: topics.first?.id
                ),
                topics: topics
            )
        }
        .errorAlert($actionError)
    }

    // MARK: Header

    @ViewBuilder
    private var headerActions: some View {
        PageSearchButton(isSearching: $isSearching, text: $searchText, focus: $searchFocused)
            .accessibilityIdentifier("decks.search")
        CircleIconButton(systemImage: "plus", label: "New Deck", kind: .soft) { isBuilding = true }
            .accessibilityIdentifier("decks.add")
    }

    /// How many decks you study.
    private var countBadge: some View {
        let count = decks.filter { !$0.isHidden }.count
        return HeaderBadge(value: count, icon: "rectangle.stack", ink: CodeyColor.brand, fill: CodeyColor.brandSoft)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(count.counted("deck"))
    }

    /// Every deck you study, and how far along you are across them.
    private var hero: some View {
        let shown = decks.filter { !$0.isHidden }
        // Counted by the store, not by loading every card (it showed up
        // when switching tabs, Nov 17). Mastered: every card in the deck is.
        let cards = (try? context.fetchCount(FetchDescriptor<Flashcard>(predicate: #Predicate {
            $0.deletedAt == nil && $0.deck?.deletedAt == nil && $0.deck?.isHidden == false
        }))) ?? 0
        let mastered = shown.filter(\.isFullyMastered).count
        // The card count as a tag, like Play's level (Nov 15).
        return HeroCard(
            title: "Decks",
            icon: "rectangle.stack",
            progress: shown.isEmpty ? 0 : Double(mastered) / Double(shown.count),
            caption: "\(mastered) of \(shown.count) decks mastered"
        ) {
            CodeyChip(cards.counted("card"), systemImage: "rectangle.stack", variant: .xp)
        }
    }

    // MARK: Sections

    private func section(_ title: String?, decks: [FlashcardDeck], topicsByID: [String: Topic]) -> some View {
        BentoSection(title, columns: .spread) {
            ForEach(decks) { deck in
                DeckTileLink(deck: deck, topic: topicsByID[deck.topicId])
            }
        }
    }

    // MARK: Filtering

    /// The search/filter result, split by origin, in one pass per render.
    /// Starter decks of pinned topics come first (onboarding, D16), in pin order.
    private func deckSections(topicsByID: [String: Topic]) -> (user: [FlashcardDeck], starter: [FlashcardDeck]) {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        var user: [FlashcardDeck] = []
        var starter: [FlashcardDeck] = []
        for deck in decks {
            if !query.isEmpty,
               !deck.title.localizedStandardContains(query),
               topicsByID[deck.topicId]?.title.localizedStandardContains(query) != true {
                continue
            }
            switch deck.origin {
            case .user: user.append(deck)
            case .starter: if showHiddenStarters || !deck.isHidden { starter.append(deck) }
            }
        }
        let pins = profiles.first?.pinnedTopicIds ?? []
        let pinRank = Dictionary(pins.enumerated().map { ($1, $0) }, uniquingKeysWith: min)
        starter.sort { lhs, rhs in
            let l = pinRank[lhs.topicId] ?? Int.max
            let r = pinRank[rhs.topicId] ?? Int.max
            if l != r { return l < r }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return (user, starter)
    }

    private var hasHiddenStarters: Bool {
        decks.contains { $0.origin == .starter && $0.isHidden }
    }
}

struct DeckRoute: Hashable {
    let id: UUID
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    NavigationStack {
        DeckLibraryView()
    }
    .environment(Router())
    .environment(BackendFacade.localOnly(context: container.mainContext))
    .modelContainer(container)
}
