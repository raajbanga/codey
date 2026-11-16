import SwiftData
import SwiftUI

/// Library tab (Nov 15): every topic, and on each topic's page its quiz,
/// exercises and decks together. Play keeps the game (quests, this week);
/// Decks keeps the deck manager. Laid out like Decks.
///
///     (▦ 8)                          (⌕) (+)   ← topics; search, New Deck
///     ╭ Library                          ╮      ← exercises solved
///     Topics
///     ╭ Algorithms    ╮ ╭ Swift         ╮       ← opens the topic page
struct LibraryView: View {
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query(filter: #Predicate<FlashcardDeck> { $0.deletedAt == nil }) private var decks: [FlashcardDeck]
    @Query private var profiles: [UserProfile]
    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]
    @Query private var records: [QuizAnswerRecord]

    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool
    @State private var isBuilding = false
    @State private var openTopic: Topic?

    @Environment(BackendFacade.self) private var backend

    private var exercises: [Exercise] { ExerciseCatalog.shared.all }

    /// Topics whose title or summary match the search.
    private var shownTopics: [Topic] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return topics }
        return topics.filter { $0.title.localizedStandardContains(query) || $0.summary.localizedStandardContains(query) }
    }

    var body: some View {
        let exerciseCounts = Dictionary(grouping: exercises, by: \.topicId).mapValues(\.count)
        let deckCounts = Dictionary(grouping: decks.filter { !$0.isHidden }, by: \.topicId).mapValues(\.count)
        let solved = Set(profiles.first?.solvedExerciseIds ?? []).intersection(exercises.map(\.id)).count
        CodeyPage("Library", isTabRoot: true) {
            PageSearchButton(isSearching: $isSearching, text: $searchText, focus: $searchFocused)
                .accessibilityIdentifier("library.search")
            CircleIconButton(systemImage: "plus", label: "New Deck", kind: .soft) { isBuilding = true }
                .accessibilityIdentifier("library.add")
        } leading: {
            HeaderBadge(value: topics.count, icon: "square.stack.3d.up", ink: CodeyColor.brand, fill: CodeyColor.brandSoft)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(topics.count.counted("topic"))
        } hero: {
            HeroCard(
                title: "Library",
                icon: "square.stack.3d.up",
                progress: exercises.isEmpty ? 0 : Double(solved) / Double(exercises.count),
                caption: "\(solved) of \(exercises.count) exercises solved"
            ) {
                CodeyChip(exercises.count.counted("exercise"), systemImage: "chevron.left.forwardslash.chevron.right", variant: .xp)
            }
        } content: {
            if isSearching {
                PageSearchField(prompt: "Topic", text: $searchText, focus: $searchFocused)
            }
            if shownTopics.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                BentoSection("Topics") {
                    ForEach(shownTopics) { topic in
                        TopicTile(
                            stats: QuizTopicStats(topic: topic, progressRows: progressRows, topicProgress: topicProgress, records: records, xp: profiles.first?.totalXP ?? 0),
                            counts: (exerciseCounts[topic.id] ?? 0, deckCounts[topic.id] ?? 0),
                            action: TileAction("Open", icon: "chevron.right")
                        ) { openTopic = topic }
                        .accessibilityIdentifier("library.topic.\(topic.title)")
                    }
                }
            }
        }
        .navigationDestination(item: $openTopic) { TopicPageView(topic: $0) }
        .navigationDestination(for: DeckRoute.self) { route in
            if let deck = decks.first(where: { $0.id == route.id }) {
                DeckDetailView(deck: deck, topic: topics.first { $0.id == deck.topicId })
            }
        }
        .sheet(isPresented: $isBuilding) {
            DeckBuilderView(
                viewModel: DeckViewModel(backend: backend, knownTopicIds: Set(topics.map(\.id)), defaultTopicId: topics.first?.id),
                topics: topics
            )
        }
    }
}

/// One topic: its quiz (the Play tile), its exercises, its decks.
struct TopicPageView: View {
    let topic: Topic

    @Environment(Router.self) private var router
    @Query private var profiles: [UserProfile]
    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]
    @Query private var records: [QuizAnswerRecord]
    @Query private var decks: [FlashcardDeck]

    init(topic: Topic) {
        self.topic = topic
        let id = topic.id
        _progressRows = Query(filter: #Predicate<QuestionProgress> { $0.topicId == id })
        _topicProgress = Query(filter: #Predicate<TopicProgress> { $0.topicId == id })
        _records = Query(filter: #Predicate<QuizAnswerRecord> { $0.topicId == id })
        _decks = Query(
            filter: #Predicate<FlashcardDeck> { $0.topicId == id && $0.deletedAt == nil && !$0.isHidden },
            sort: \.title
        )
    }

    var body: some View {
        let profile = profiles.first
        let stats = QuizTopicStats(topic: topic, progressRows: progressRows, topicProgress: topicProgress, records: records, xp: profile?.totalXP ?? 0)
        let tier = stats.tiers.last(where: \.isUnlocked)?.difficulty ?? .easy
        let hue = CodeyColor.TopicHue.of(topicID: topic.id)
        // The topic's quiz is the page's hero: the same bar and tags as
        // its tile on Play, then Play.
        CodeyPage(topic.title) {
            HeroCard(
                title: topic.title,
                subtitle: topic.summary,
                icon: topic.iconName,
                hue: hue,
                progress: stats.accuracy ?? 0,
                caption: stats.accuracy.map { "\($0.percentText) correct lately" } ?? "No answers yet"
            ) {
                CodeyChip(xp: XPPolicy.base(tier))
            }
        } content: {
            CodeyButton("Play Quiz", systemImage: "play", kind: .hue(hue), fullWidth: true) {
                router.quizSetupTopic = topic
            }
            .accessibilityIdentifier("topic.play")
            if ExerciseCatalog.shared.all.contains(where: { $0.topicId == topic.id }) {
                BentoSection("Exercises") {
                    ExerciseTiles(topics: [topic], solved: Set(profile?.solvedExerciseIds ?? []), topicID: topic.id)
                }
            }
            if !decks.isEmpty {
                BentoSection("Decks") {
                    ForEach(decks) { DeckTileLink(deck: $0, topic: topic) }
                }
            }
        }
    }
}
