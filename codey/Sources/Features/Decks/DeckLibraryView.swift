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

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<FlashcardDeck> { $0.deletedAt == nil },
        sort: [SortDescriptor(\FlashcardDeck.updatedAt, order: .reverse)]
    )
    private var decks: [FlashcardDeck]
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query private var profiles: [UserProfile]

    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var showHiddenStarters = false
    @State private var builder: BuilderRequest?
    @State private var deckToDelete: FlashcardDeck?
    @State private var actionError: String?

    private var topicsByID: [String: Topic] {
        Dictionary(topics.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var backend: LocalOnlyBackend { LocalOnlyBackend(context: modelContext) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
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
                } else if userDecks.isEmpty && starterDecks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    if filter != .starter, !userDecks.isEmpty {
                        section(filter == .all ? "My Decks" : nil, decks: userDecks)
                    }
                    if filter != .mine, !starterDecks.isEmpty {
                        section(filter == .all ? "Starter Decks" : nil, decks: starterDecks)
                    }
                    if filter == .mine, userDecks.isEmpty {
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
        .background(CodeyColor.surface)
        .navigationTitle("Decks")
        .searchable(text: $searchText, prompt: "Title or topic")
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
            isPresented: Binding(get: { deckToDelete != nil }, set: { if !$0 { deckToDelete = nil } }),
            titleVisibility: .visible,
            presenting: deckToDelete
        ) { deck in
            Button("Delete Deck", role: .destructive) { perform { try backend.deleteDeck(deck) } }
        } message: { deck in
            Text("All \(deck.cardCount) cards will be deleted. This can't be undone.")
        }
        .alert("Something Went Wrong", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: Sections

    private func section(_ title: String?, decks: [FlashcardDeck]) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            if let title {
                Text(title)
                    .font(.codeyTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 170), spacing: CodeySpacing.sm + CodeySpacing.xs)],
                spacing: CodeySpacing.sm + CodeySpacing.xs
            ) {
                ForEach(decks) { deck in
                    NavigationLink(value: DeckRoute(id: deck.id)) {
                        DeckTile(deck: deck, topic: topicsByID[deck.topicId])
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: deck) }
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for deck: FlashcardDeck) -> some View {
        if deck.isEditable {
            Button("Edit", systemImage: "pencil") { builder = .edit(deck) }
            Button("Delete", systemImage: "trash", role: .destructive) { deckToDelete = deck }
                .disabled(!deck.canDelete)
            if let reason = deck.deleteBlockedReason {
                Text(reason)
            }
        } else if deck.isHidden {
            Button("Restore", systemImage: "eye") { perform { try backend.setHidden(false, deck: deck) } }
        } else {
            Button("Hide", systemImage: "eye.slash") { perform { try backend.setHidden(true, deck: deck) } }
        }
    }

    // MARK: Filtering

    private var visibleDecks: [FlashcardDeck] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return decks }
        return decks.filter { deck in
            deck.title.localizedStandardContains(query)
                || (topicsByID[deck.topicId]?.title.localizedStandardContains(query) ?? false)
        }
    }

    private var userDecks: [FlashcardDeck] {
        visibleDecks.filter { $0.origin == .user }
    }

    private var starterDecks: [FlashcardDeck] {
        visibleDecks
            .filter { $0.origin == .starter && (showHiddenStarters || !$0.isHidden) }
            .sorted { lhs, rhs in
                // Pinned topics' starter decks first (onboarding, D16), in pin order.
                let pins = profiles.first?.pinnedTopicIds ?? []
                let l = pins.firstIndex(of: lhs.topicId) ?? Int.max
                let r = pins.firstIndex(of: rhs.topicId) ?? Int.max
                if l != r { return l < r }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var hasHiddenStarters: Bool {
        decks.contains { $0.origin == .starter && $0.isHidden }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            actionError = error.localizedDescription
        }
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
    NavigationStack {
        DeckLibraryView()
    }
    .environment(Router())
    .modelContainer(ModelContainerFactory.makePreview())
}
