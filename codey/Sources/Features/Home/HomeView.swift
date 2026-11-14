import SwiftData
import SwiftUI

/// Home (D8, simplified r3; Sprint 3 S9 facelift; S40 bento): progress at a
/// glance plus ONE suggestion, then bento grids (Bento.swift) for the plan,
/// challenge and groups, and every topic.
///
///     Good evening                          (◎)
///     Codey Learner
///     Level 4                   1,840 XP  🔥 3    ← LevelSummary (streak, FR-33)
///     ━━━━━━━━━━━━━━━━━━━━━━────────
///     160 XP to Level 5          Today 12/20     ← daily goal (FR-32)
///     ╭ Up next: ▶ Continue Swift Closures 7/12 ╮   ← one action
///     This week's plan                            ← FR-38, fixed for the week
///     ╭ ◆ Networking · Not started            ›  ╮
///     │ ◆ Databases · 41% accuracy             › │
///     ╰ ◆ Algorithms · 58% accuracy            › ╯
///     Your topics (all; pinned first)
///     ╭ ◆ Data Structures                       ╮   ← one note per topic
///     │ 42% mastered · 78% accuracy             │
///     │ ━━━━━━──────────      [Cards] [Quiz]    │  ← mastery; deck (menu if several) / quiz setup
///     ╰─────────────────────────────────────────╯
///     ╭ ◆ Algorithms …                          ╮
///     ╰─────────────────────────────────────────╯
///
/// Everything else lives in its tab (Decks, Quiz); Home doesn't duplicate it.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(BackendFacade.self) private var backend
    @AppStorage("home.signInNudgeDismissed") private var nudgeDismissed = false
    /// FR-38: this week's plan (JSON StudyPlan), so it doesn't reshuffle.
    @AppStorage("home.studyPlan") private var studyPlanData = Data()

    @Query private var profiles: [UserProfile]
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query(filter: #Predicate<FlashcardDeck> { $0.deletedAt == nil }) private var decks: [FlashcardDeck]
    @Query(sort: [SortDescriptor(\StudyProgressSnapshot.updatedAt, order: .reverse)])
    private var snapshots: [StudyProgressSnapshot]
    /// Newest first: HomeStats takes each topic's newest answers. Bounded
    /// by QuizProgressStore's per-topic history cap.
    @Query(sort: \QuizAnswerRecord.answeredAt, order: .reverse) private var records: [QuizAnswerRecord]
    @Query private var activity: [DailyActivity]

    private var profile: UserProfile? { profiles.first }
    private var xp: Int { profile?.totalXP ?? 0 }
    private var pinned: [String] { profile?.pinnedTopicIds ?? [] }

    var body: some View {
        let stats = HomeStats(records: records, decks: decks, snapshots: snapshots)
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                PageHeader(eyebrow: HomeLogic.greeting(at: .now), title: profile?.username ?? UserProfile.defaultUsername)
                LevelSummary(
                    xp: xp,
                    streak: StreakCalculator.currentStreak(endingOn: .now, activity: activity),
                    today: StreakCalculator.progress(of: activity.first { $0.day == DailyActivity.dayKey(for: .now) })
                )
                upNextCard(stats)
                planSection(stats)
                weekSection
                topicsSection(stats)
                if showsSignInNudge {
                    signInNudge
                }
            }
            .padding(CodeySpacing.md)
        }
        .codeyPaperBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.showProfile = true
                } label: {
                    Icon("person.crop.circle", size: 26, relativeTo: .title2)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                .accessibilityLabel("Profile")
                .accessibilityIdentifier("home.profile")
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            refreshPlan(stats)
            LaunchTimer.markHomeReady()
        }
        .onChange(of: topics.map(\.id)) { refreshPlan(stats) }
    }

    // MARK: Up next

    private func upNext(_ stats: HomeStats) -> HomeLogic.UpNext {
        let resumable = snapshots.first { snapshot in
            stats.deckByID[snapshot.deckId] != nil && snapshot.position < snapshot.cardIDs.count
        }
        return HomeLogic.upNext(
            resumable: resumable.map { ($0.deckId, $0.queue.displayPosition, $0.queue.distinctTotal) },
            isNewLearner: isNewLearner,
            starterDeckID: suggestedStarterDeck?.id,
            weakestTopicID: HomeLogic.weakestTopicID(candidates: quizCandidates, accuracy: stats.accuracyByTopic)
        )
    }

    @ViewBuilder
    private func upNextCard(_ stats: HomeStats) -> some View {
        switch upNext(stats) {
        case .resume(let deckID, let position, let total):
            if let deck = stats.deckByID[deckID] {
                UpNextCard(
                    eyebrow: "Continue studying",
                    title: deck.title,
                    detail: "Card \(position) of \(total)",
                    systemImage: "play.fill",
                    progress: total == 0 ? nil : Double(position - 1) / Double(total)
                ) { router.study = StudyRequest(deck: deck, start: .resume) }
            }
        case .startDeck(let deckID):
            if let deck = stats.deckByID[deckID] {
                UpNextCard(
                    eyebrow: "Start here",
                    title: deck.title,
                    detail: "Flip cards and swipe to rate. Takes about 5 minutes.",
                    systemImage: "sparkles"
                ) { router.study = StudyRequest(deck: deck, start: .fresh(tierFilter: nil)) }
            }
        case .quiz(let topicID):
            if let topic = topics.first(where: { $0.id == topicID }) {
                UpNextCard(
                    eyebrow: "Suggested quiz",
                    title: topic.title,
                    detail: stats.accuracyByTopic[topicID].map { "Your weakest topic · \($0.percentText) accuracy" } ?? "You haven't quizzed this topic yet",
                    systemImage: "questionmark.bubble.fill"
                ) { router.quizSetupTopic = topic }
            }
        case .none:
            EmptyView()
        }
    }

    // MARK: Weekly plan (FR-38)

    private var plannedTopics: [Topic] {
        guard let plan = try? JSONDecoder().decode(StudyPlan.self, from: studyPlanData) else { return [] }
        let byID = topics.keyed(by: \.id)
        return plan.topicIDs.compactMap { byID[$0] }
    }

    /// Keeps the cached plan while it's this week's; rebuilds on Monday.
    private func refreshPlan(_ stats: HomeStats) {
        let cached = try? JSONDecoder().decode(StudyPlan.self, from: studyPlanData)
        let plan = StudyPlan.current(cached: cached, now: .now, knownTopicIDs: Set(topics.map(\.id))) {
            StudyPlanBuilder.build(topicIDs: topics.map(\.id), answerCounts: stats.answerCounts, accuracy: stats.accuracyByTopic)
        }
        if plan != cached, let data = try? JSONEncoder().encode(plan) {
            studyPlanData = data
        }
    }

    @ViewBuilder
    private func planSection(_ stats: HomeStats) -> some View {
        let planned = plannedTopics
        if !planned.isEmpty {
            BentoSection("This week's plan") {
                ForEach(planned) { topic in
                    Button { router.quizSetupTopic = topic } label: {
                        BentoTile(
                            icon: topic.iconName,
                            title: topic.title,
                            detail: planAccuracy(topic, stats).map { "\($0.percentText) accuracy" } ?? "Not started",
                            minHeight: 0
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens quiz setup")
                    .accessibilityIdentifier("home.plan.\(topic.title)")
                }
            }
        }
    }

    // MARK: This week (FR-42, FR-43)

    private var challenge: WeeklyChallenge.Status? {
        WeeklyChallenge.status(now: .now, topicIDs: topics.map(\.id), records: records)
    }

    private var weekSection: some View {
        BentoSection("Challenge and groups") {
            if let challenge, let topic = topics.first(where: { $0.id == challenge.topicID }) {
                Button { router.quizSetupTopic = topic } label: {
                    BentoTile(
                        icon: challenge.isComplete ? "trophy.fill" : "flag.checkered",
                        title: "Weekly challenge",
                        detail: challenge.isComplete
                            ? "Done this week"
                            : "\(min(challenge.correct, WeeklyChallenge.goal)) of \(WeeklyChallenge.goal) correct in \(topic.title)"
                    ) {
                        ProgressBar(value: challenge.progress)
                    }
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens quiz setup")
                .accessibilityIdentifier("home.challenge")
            }
            NavigationLink {
                GroupsView()
            } label: {
                BentoTile(icon: "person.3.fill", title: "Groups", detail: "Weekly XP leaderboard")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.groups")
        }
    }

    /// Live accuracy, or nil while the topic has too few answers to judge.
    private func planAccuracy(_ topic: Topic, _ stats: HomeStats) -> Double? {
        stats.answerCounts[topic.id, default: 0] >= StudyPlanBuilder.minimumAnswers ? stats.accuracyByTopic[topic.id] : nil
    }

    // MARK: Topics

    /// Every topic, pinned first.
    private var orderedTopics: [Topic] {
        let ids = HomeLogic.orderedTopicIDs(all: topics.map { ($0.id, $0.title) }, pinned: pinned)
        let byID = topics.keyed(by: \.id)
        return ids.compactMap { byID[$0] }
    }

    /// The suggested quiz picks from pinned topics, or all if none are pinned.
    private var quizCandidates: [String] {
        let known = Set(topics.map(\.id))
        let pins = pinned.filter(known.contains)
        return pins.isEmpty ? topics.map(\.id) : pins
    }

    private func topicsSection(_ stats: HomeStats) -> some View {
        BentoSection("Your topics") {
            ForEach(orderedTopics) { topic in
                TopicTile(
                    topic: topic,
                    isPinned: pinned.contains(topic.id),
                    decks: stats.decksByTopic[topic.id] ?? [],
                    snapshotDeckIDs: stats.snapshotDeckIDs,
                    accuracy: stats.accuracyByTopic[topic.id],
                    practice: { deck, resume in
                        router.study = StudyRequest(deck: deck, start: resume ? .resume : .fresh(tierFilter: nil))
                    },
                    quiz: { router.quizSetupTopic = topic }
                )
            }
        }
    }

    // MARK: Data

    /// No quiz answers and no studied cards yet.
    private var isNewLearner: Bool {
        records.isEmpty && !decks.contains { deck in deck.unorderedActiveCards.contains { $0.lastReviewedAt != nil } }
    }

    /// The starter deck for the first pinned topic (or any starter deck).
    private var suggestedStarterDeck: FlashcardDeck? {
        let starters = decks.filter { $0.origin == .starter && !$0.isHidden }
        for topicID in pinned {
            if let deck = starters.first(where: { $0.topicId == topicID }) { return deck }
        }
        return starters.min { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: Sign-in nudge

    /// Only when sign-in is possible in this build and the user is a guest.
    private var showsSignInNudge: Bool {
        backend.isSignInAvailable && backend.currentUser == nil && !nudgeDismissed
    }

    private var signInNudge: some View {
        CodeyCard(tint: CodeyColor.brand) {
            HStack(alignment: .top, spacing: CodeySpacing.sm) {
                Icon("icloud.and.arrow.up", size: 26, relativeTo: .title2)
                    .foregroundStyle(CodeyColor.brand)
                VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                    Text("Back up your decks")
                        .font(.codeyHeadline)
                    Text("Sign in from your profile to sync decks and XP across devices.")
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                Spacer(minLength: 0)
                CloseButton(label: "Dismiss") {
                    withAnimation(CodeyMotion.snappy) { nudgeDismissed = true }
                }
            }
        }
        .onTapGesture { router.showProfile = true }
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    NavigationStack {
        HomeView()
    }
    .environment(Router())
    .environment(BackendFacade.localOnly(context: container.mainContext))
    .modelContainer(container)
}
