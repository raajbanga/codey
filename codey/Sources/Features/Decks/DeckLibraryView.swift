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
    @State private var showHiddenStarters = false
    @State private var builder: BuilderRequest?
    @State private var deckToDelete: FlashcardDeck?
    @State private var actionError: String?

    @Environment(BackendFacade.self) private var backend
    @Environment(Router.self) private var router

    var body: some View {
        let topicsByID = topics.keyed(by: \.id)
        let sections = deckSections(topicsByID: topicsByID)
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                PageHeader(title: "Decks")
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if decks.isEmpty {
                    EmptyStateView(
                        systemImage: "rectangle.stack.badge.plus",
                        title: "Make your first deck",
                        message: "Write your own prompt/answer cards, with code if you like.",
                        actionTitle: "New Deck",
                        action: { builder = .new }
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
                            action: { builder = .new }
                        )
                    }
                }

                if filter != .mine, hasHiddenStarters {
                    Toggle("Show hidden starter decks", isOn: $showHiddenStarters)
                        .font(.codeyCallout)
                        .tint(CodeyColor.brand)
                }
            }
            .padding(CodeySpacing.md)
        }
        .codeyPaperBackground()
        .toolbarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Title or topic")
        // A toolbar button that expands, so the field doesn't sit above the
        // page title (S40).
        .searchToolbarBehavior(.minimize)
        .refreshable { await backend.syncPending() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    builder = .new
                } label: {
                    Label("New Deck", systemImage: "plus")
                }
                .accessibilityIdentifier("decks.add")
            }
        }
        .navigationDestination(for: DeckRoute.self) { route in
            if let deck = decks.first(where: { $0.id == route.id }) {
                DeckDetailView(deck: deck, topic: topicsByID[deck.topicId])
            }
        }
        .sheet(item: $builder) { request in
            DeckBuilderView(
                viewModel: DeckViewModel(
                    backend: backend,
                    knownTopicIds: Set(topics.map(\.id)),
                    editing: request.deck,
                    defaultTopicId: topics.first?.id
                ),
                topics: topics
            )
        }
        .confirmationDialog(
            "Delete \"\(deckToDelete?.title ?? "")\"?",
            isPresented: $deckToDelete.isPresent(),
            titleVisibility: .visible,
            presenting: deckToDelete
        ) { deck in
            Button("Delete Deck", role: .destructive) { $actionError.attempt { try backend.deleteDeck(deck) } }
        } message: { deck in
            Text("All \(deck.cardCount) cards will be deleted. This can't be undone.")
        }
        .errorAlert($actionError)
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
                    .contextMenu { menu(for: deck) }
                    // S40: study straight from the grid (continues where you
                    // left off); the deck screen keeps tier and start-over options.
                    .overlay(alignment: .bottomTrailing) {
                        if canStudy {
                            CircleIconButton(systemImage: "play.fill", label: "Study \(deck.title)", kind: .filled) {
                                router.study = StudyRequest(deck: deck, start: .resume)
                            }
                            .padding(CodeySpacing.sm)
                            .accessibilityIdentifier("deckTile.study.\(deck.title)")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func menu(for deck: FlashcardDeck) -> some View {
        if deck.isEditable {
            Button("Edit", systemImage: "pencil") { builder = .edit(deck) }
                .disabled(!deck.canEdit)
            Button("Delete", systemImage: "trash", role: .destructive) { deckToDelete = deck }
                .disabled(!deck.canDelete)
            if let reason = deck.deleteBlockedReason {
                Text(reason)
            }
        } else if deck.isHidden {
            Button("Restore", systemImage: "eye") { $actionError.attempt { try backend.setHidden(false, deck: deck) } }
        } else {
            Button("Hide", systemImage: "eye.slash") { $actionError.attempt { try backend.setHidden(true, deck: deck) } }
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

/// Which deck the builder sheet opens on.
enum BuilderRequest: Identifiable {
    case new
    case edit(FlashcardDeck)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let deck): deck.id.uuidString
        }
    }

    var deck: FlashcardDeck? {
        if case .edit(let deck) = self { return deck }
        return nil
    }
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
