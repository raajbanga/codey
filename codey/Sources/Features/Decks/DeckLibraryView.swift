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

    var body: some View {
        let topicsByID = topics.keyed(by: \.id)
        let sections = deckSections(topicsByID: topicsByID)
        CodeyPage("Decks", isTabRoot: true) {
            headerActions
        } hero: {
            hero
        } content: {
            if isSearching {
                searchField
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
            CircleIconButton(systemImage: isSearching ? "xmark" : "magnifyingglass", label: isSearching ? "Close search" : "Search", kind: .soft) {
                withAnimation(CodeyMotion.snappy) {
                    isSearching.toggle()
                    if !isSearching { searchText = "" }
                }
                searchFocused = isSearching
            }
            .accessibilityIdentifier("decks.search")
            CircleIconButton(systemImage: "plus", label: "New Deck", kind: .soft) { isBuilding = true }
                .accessibilityIdentifier("decks.add")
    }

    /// Every deck you study, and how far along you are across them.
    private var hero: some View {
        let shown = decks.filter { !$0.isHidden }
        let cards = shown.reduce(0) { $0 + $1.cardCount }
        let progress = cards == 0 ? 0 : shown.reduce(0.0) { $0 + $1.progressRate * Double($1.cardCount) } / Double(cards)
        return HeroCard(
            title: "Decks",
            subtitle: "\(shown.count.counted("deck")), \(cards.counted("card"))",
            icon: "rectangle.stack",
            progress: progress,
            caption: "\(progress.percentText) progress"
        )
    }

    private var searchField: some View {
        HStack(spacing: CodeySpacing.sm) {
            Icon("magnifyingglass", size: 18, relativeTo: .body)
                .foregroundStyle(CodeyColor.textSecondary)
            TextField("Title or topic", text: $searchText)
                .font(.codeyBody)
                .focused($searchFocused)
                .submitLabel(.search)
                .accessibilityIdentifier("decks.searchField")
        }
        .padding(.horizontal, CodeySpacing.md)
        .frame(minHeight: 44)
        .background(CodeyColor.surfaceRaised, in: .pill)
        .overlay { RoundedRectangle.pill.strokeBorder(CodeyColor.separator, lineWidth: 1) }
        .transition(.opacity)
    }

    // MARK: Sections

    private func section(_ title: String?, decks: [FlashcardDeck], topicsByID: [String: Topic]) -> some View {
        BentoSection(title) {
            ForEach(decks) { deck in
                let canStudy = deck.cardCount > 0 && !deck.isHidden
                NavigationLink(value: DeckRoute(id: deck.id)) {
                    DeckTile(deck: deck, topic: topicsByID[deck.topicId], reservesStudyButton: canStudy)
                }
                .buttonStyle(.plain)
                // S40: study straight from the grid (continues where you
                // left off); the deck screen keeps tier and start-over options.
                .overlay(alignment: .bottom) {
                    if canStudy {
                        Button {
                            router.study = StudyRequest(deck: deck, start: .resume)
                        } label: {
                            TileActionLabel(action: TileAction("Study"), hue: .of(topicID: deck.topicId))
                        }
                        .buttonStyle(TilePressStyle())
                        .padding(CodeySpacing.md)
                        .accessibilityLabel("Study \(deck.title)")
                        .accessibilityIdentifier("deckTile.study.\(deck.title)")
                    }
                }
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
