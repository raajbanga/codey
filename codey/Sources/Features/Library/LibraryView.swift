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

    /// Pinned topics first (in pin order, set in Settings), then the rest
    /// by title; filtered by the search.
    private var shownTopics: [Topic] {
        let byID = topics.keyed(by: \.id)
        let ordered = HomeLogic.orderedTopicIDs(all: topics.map { ($0.id, $0.title) }, pinned: profiles.first?.pinnedTopicIds ?? [])
            .compactMap { byID[$0] }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return ordered }
        return ordered.filter { $0.title.localizedStandardContains(query) || $0.summary.localizedStandardContains(query) }
    }

    var body: some View {
        let challenges = ChallengeCatalog.shared.all
        let exerciseCounts = Dictionary(grouping: exercises, by: \.topicId).mapValues(\.count)
        let challengeCounts = Dictionary(grouping: challenges, by: \.topicId).mapValues(\.count)
        let completed = completedTopics(challenges: challenges)
        let shown = shownTopics
        let stats = QuizTopicStats.byTopic(shown, progressRows: progressRows, topicProgress: topicProgress, records: records, xp: profiles.first?.totalXP ?? 0)
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
                progress: topics.isEmpty ? 0 : Double(completed) / Double(topics.count),
                caption: "\(completed) of \(topics.count) topics completed"
            ) {
                CodeyChip((exercises.count + challenges.count).counted("activity", plural: "activities"), systemImage: "checklist", variant: .xp)
            }
        } content: {
            if isSearching {
                PageSearchField(prompt: "Topic", text: $searchText, focus: $searchFocused)
            }
            if shown.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                BentoSection("Topics", columns: .spread) {
                    ForEach(shown) { topic in
                        TopicTile(
                            stats: stats[topic.id]!,
                            activities: (exerciseCounts[topic.id] ?? 0) + (challengeCounts[topic.id] ?? 0),
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

extension LibraryView {
    /// A topic is completed when every drill and challenge in it is solved
    /// (topics with neither don't count as completed).
    private func completedTopics(challenges: [Challenge]) -> Int {
        let solved = Set(profiles.first?.solvedExerciseIds ?? [])
        let items = Dictionary(grouping: exercises.map { ($0.topicId, $0.id) } + challenges.map { ($0.topicId, $0.id) }, by: \.0)
        return topics.filter { topic in
            guard let ids = items[topic.id], !ids.isEmpty else { return false }
            return ids.allSatisfy { solved.contains($0.1) }
        }.count
    }
}

/// One topic: its quiz (the Play tile), its challenges, drills and decks.
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
        // Activities: the topic's drills and challenges, done once solved.
        let solved = Set(profile?.solvedExerciseIds ?? [])
        let drills = ExerciseCatalog.shared.all.filter { $0.topicId == topic.id }
        let challenges = ChallengeCatalog.shared.all.filter { $0.topicId == topic.id }
        let activities = drills.map(\.id) + challenges.map(\.id)
        let done = activities.filter(solved.contains).count
        // The topic's quiz is the page's hero: the same bar and tags as
        // its tile on Play, then Play.
        CodeyPage(topic.title, hero: {
            HeroCard(
                title: topic.title,
                subtitle: topic.summary,
                icon: topic.iconName,
                hue: hue,
                progress: activities.isEmpty ? 0 : Double(done) / Double(activities.count),
                caption: "\(done) of \(activities.count) activities completed"
            ) {
                CodeyChip(xp: XPPolicy.base(tier))
            }
        }) {
            CodeyButton("Play Quiz", systemImage: "play", kind: .hue(hue), fullWidth: true) {
                router.quizSetupTopic = topic
            }
            .accessibilityIdentifier("topic.play")
            if !challenges.isEmpty {
                BentoSection("Challenges", count: challenges.count) {
                    ChallengeTiles(solved: solved, topicID: topic.id)
                }
            }
        } trailing: {
            // iPad landscape and Mac: the decks, then the drills, are the
            // second column, so neither column is one long list.
            if !decks.isEmpty {
                BentoSection("Decks", count: decks.count) {
                    ForEach(decks) { DeckTileLink(deck: $0, topic: topic) }
                }
            }
            if !drills.isEmpty {
                BentoSection("Drills", count: drills.count) {
                    ExerciseTiles(topics: [topic], solved: solved, topicID: topic.id)
                }
            }
        }
    }
}
