import SwiftData
import SwiftUI

/// Play (S41, the game layer; was Home), laid out as the S41 mockup: few
/// words, big targets, color per topic, on the dotted paper.
///
///     🔥4                            (▲) (◎)  ← streak; groups, profile
///     ╭ (avatar)                   [Level 3] ╮   ← HeroCard, app hue
///     │ Codey Learner                        │
///     │ Good evening                         │
///     │ ████████████░░░░░░                   │
///     ╰ 320 / 500 XP, 180 to Level 4         ╯
///     Today's quests
///     ╭ ◎ Answer 20   ╮ ╭ ⚑ 15 right in…  ╮      ← next quest large,
///     │ ━━━━──        │ ╰─────────────────╯         the others stacked
///     ╰ [  ▶ Play  ]  ╯ ╭ ▭ Warm up: SQL  ╮         small (1½)
///     This week
///     ╭ Algorithms    ╮ ╭ Data Structures ╮      ← whole tile plays
///
/// Every topic, with its exercises and decks, is in the Library tab.
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
    /// Other devices' daily counters (S43), so the goal and streak add up.
    @Query private var otherActivity: [DeviceDayActivity]
    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]

    private var profile: UserProfile? { profiles.first }
    private var xp: Int { profile?.totalXP ?? 0 }
    private var pinned: [String] { profile?.pinnedTopicIds ?? [] }

    var body: some View {
        let stats = HomeStats(records: records, decks: decks, snapshots: snapshots)
        CodeyPage("Play", isTabRoot: true) {
            pageActions
        } leading: {
            streakBadge
        } hero: {
            levelHero
        } content: {
            questsSection(stats)
            topicsSection(stats)
            if showsSignInNudge {
                signInNudge
            }
        }
        .onAppear {
            refreshPlan(stats)
            LaunchTimer.markHomeReady()
        }
        .onChange(of: topics.map(\.id)) { refreshPlan(stats) }
    }

    // MARK: Warm-up suggestion

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

    // MARK: Header

    /// Always shown, 0 included (FR-37: the current streak).
    private var streakBadge: some View {
        let streak = StreakCalculator.currentStreak(endingOn: .now, totals: dayTotals)
        return HeaderBadge(value: streak, icon: "flame", ink: CodeyColor.xp, fill: CodeyColor.xpSoft)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak")
    }

    @ViewBuilder
    private var pageActions: some View {
        NavigationLink {
            GroupsView()
        } label: {
            CircleIcon(systemImage: "trophy", kind: .soft)
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel("Groups and leaderboard")
        .accessibilityIdentifier("home.groups")
        CircleIconButton(systemImage: ProfileAvatar.glyph(for: ProfileAvatar.symbol(for: profile?.avatarId)), label: "Profile", kind: .soft) {
            router.showProfile = true
        }
        .accessibilityIdentifier("home.profile")
    }

    /// Who you are and how far to the next level, in one card.
    private var levelHero: some View {
        let level = LevelCalculator.level(forXP: xp)
        return HeroCard(
            title: profile?.username ?? UserProfile.defaultUsername,
            subtitle: HomeLogic.greeting(at: .now),
            icon: ProfileAvatar.glyph(for: ProfileAvatar.symbol(for: profile?.avatarId)),
            progress: LevelCalculator.progressFraction(xp),
            caption: "\(LevelCalculator.xpIntoLevel(xp)) / \(LevelCalculator.xpPerLevel) XP, \(LevelCalculator.xpToNextLevel(xp)) to Level \(level + 1)"
        ) {
            CodeyChip("Level \(level)", systemImage: "star.fill", variant: .xp)
                .contentTransition(.numericText(value: Double(level)))
        }
        .codeyAnimation(CodeyMotion.snappy, value: xp)
        .accessibilityIdentifier("play.level")
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

    /// Topics in this week's plan get a "This week" tag on their tile.
    private var planIDs: Set<String> { Set(plannedTopics.map(\.id)) }

    // MARK: Quests (FR-32, FR-42, S41 bonuses)

    private var dayTotals: [String: Int] {
        StreakCalculator.dayTotals(own: activity, others: otherActivity)
    }

    private var todayCount: Int {
        dayTotals[DailyActivity.dayKey(for: .now)] ?? 0
    }

    private var challenge: WeeklyChallenge.Status? {
        WeeklyChallenge.status(now: .now, topicIDs: topics.map(\.id), records: records)
    }

    /// One quest on Play: what it shows and what tapping it does.
    private struct Quest: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let progress: Double
        let bonus: Int?
        let isPaid: Bool
        let hue: CodeyColor.TopicHue
        let accessibilityLabel: String
        let start: () -> Void
    }

    /// Today's goal and the weekly challenge (both open quiz setup), and a
    /// deck to warm up with (cards pay +5 XP for each card moved up). The
    /// first unpaid one is large; the rest sit small, side by side.
    private func quests(_ stats: HomeStats) -> [Quest] {
        var quests: [Quest] = []
        let goal = GatingConfig.standard.dailyGoal
        let done = min(todayCount, goal)
        let dailyPaid = profile?.goalBonusDay == DailyActivity.dayKey(for: .now)
        if !topics.isEmpty {
            quests.append(Quest(
                id: "play.quest.daily", icon: "target", title: "Answer \(goal)", detail: "\(done) of \(goal) today",
                progress: Double(done) / Double(goal), bonus: XPRewards.dailyGoalBonus, isPaid: dailyPaid, hue: .teal,
                accessibilityLabel: "Daily goal: \(done) of \(goal) answers or cards, \(dailyPaid ? "bonus paid" : "plus \(XPRewards.dailyGoalBonus) XP")"
            ) { router.quizSetupTopic = plannedTopics.first ?? orderedTopics.first })
        }
        if let challenge, let topic = topics.first(where: { $0.id == challenge.topicID }) {
            let paid = profile?.challengeBonusWeek == UTCWeek.key(for: .now)
            let right = min(challenge.correct, WeeklyChallenge.goal)
            quests.append(Quest(
                id: "home.challenge", icon: "flag.checkered", title: "\(WeeklyChallenge.goal) right in \(topic.title)",
                detail: "\(right) of \(WeeklyChallenge.goal) this week", progress: challenge.progress,
                bonus: XPRewards.weeklyChallengeBonus, isPaid: paid, hue: .coral,
                accessibilityLabel: "Weekly challenge: \(right) of \(WeeklyChallenge.goal) right in \(topic.title), \(paid ? "bonus paid" : "plus \(XPRewards.weeklyChallengeBonus) XP")"
            ) { router.quizSetupTopic = topic })
        }
        if let pick = warmUpDeck(stats) {
            quests.append(Quest(
                id: "home.upNext", icon: "rectangle.stack", title: pick.title, detail: pick.detail,
                progress: pick.deck.progressRate, bonus: XPRewards.cardMovedUp, isPaid: false, hue: .of(topicID: pick.deck.topicId),
                accessibilityLabel: "\(pick.title). \(pick.detail)"
            ) { router.study = StudyRequest(deck: pick.deck, start: pick.resume ? .resume : .fresh(tierFilter: nil)) })
        }
        return quests
    }

    /// The deck to warm up with: the session in progress, the starter deck,
    /// or a deck in the suggested topic.
    private func warmUpDeck(_ stats: HomeStats) -> (deck: FlashcardDeck, resume: Bool, title: String, detail: String)? {
        switch upNext(stats) {
        case .resume(let deckID, let position, let total):
            stats.deckByID[deckID].map { ($0, true, "Continue \($0.title)", "Card \(position) of \(total)") }
        case .startDeck(let deckID):
            stats.deckByID[deckID].map { ($0, false, "Warm up: \($0.title)", $0.cardCount.counted("card")) }
        case .quiz(let topicID):
            stats.decksByTopic[topicID]?.first.map { ($0, false, "Warm up: \($0.title)", $0.cardCount.counted("card")) }
        case .none:
            nil
        }
    }

    /// The next quest large on the left, the other two stacked on the
    /// right (a mixed fraction); one quest alone takes the row.
    @ViewBuilder
    private func questsSection(_ stats: HomeStats) -> some View {
        let all = quests(stats)
        if let large = all.first(where: { !$0.isPaid }) ?? all.first {
            let small = all.filter { $0.id != large.id }
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                SectionTitle("Today's quests")
                HStack(alignment: .top, spacing: CodeySpacing.sm + CodeySpacing.xs) {
                    questButton(large, isLarge: true)
                    if !small.isEmpty {
                        VStack(spacing: CodeySpacing.sm + CodeySpacing.xs) {
                            ForEach(small) { questButton($0, isLarge: false) }
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func questButton(_ quest: Quest, isLarge: Bool) -> some View {
        Button(action: quest.start) {
            QuestTile(
                icon: quest.icon, title: quest.title, detail: quest.detail, progress: quest.progress,
                bonus: quest.bonus, isPaid: quest.isPaid, hue: quest.hue, isLarge: isLarge
            )
        }
        .buttonStyle(TilePressStyle())
        .disabled(quest.isPaid)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(quest.accessibilityLabel)
        .accessibilityAddTraits(quest.isPaid ? [] : .isButton)
        .accessibilityIdentifier(quest.id)
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

    /// This week's plan (FR-38); every topic, and its exercises and decks,
    /// is in the Library tab (Nov 15). Pinned topics if there's no plan yet.
    private func topicsSection(_ stats: HomeStats) -> some View {
        let plan = planIDs
        let shown = plan.isEmpty ? orderedTopics.filter { pinned.contains($0.id) } : orderedTopics.filter { plan.contains($0.id) }
        return BentoSection("This week") {
            ForEach(shown) { topic in
                TopicTile(stats: quizStats(for: topic)) {
                    router.quizSetupTopic = topic
                }
                .accessibilityIdentifier("play.topic.\(topic.title).quiz")
            }
        }
    }

    private func quizStats(for topic: Topic) -> QuizTopicStats {
        QuizTopicStats(topic: topic, progressRows: progressRows, topicProgress: topicProgress, records: records, xp: xp)
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
