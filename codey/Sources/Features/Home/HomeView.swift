import SwiftData
import SwiftUI

/// Play (S41, the game layer; was Home), laid out as the S41 mockup: few
/// words, big targets, color per topic, on the dotted paper.
///
///     Good evening                  🔥4 (▲) (◎)  ← streak, groups, profile
///     Codey Learner
///     ╭ Level 3                 320 / 500 XP ╮   ← LevelHero, slate
///     │ ████████████░░░░░░                   │
///     ╰ 180 XP to Level 4                    ╯
///     Today's quests
///     ╭ ◎ Answer 20   ╮ ╭ ⚑ 15 right in   ╮      ← bonus XP, paid once
///     │ ━━━──  +50 XP │ │ Python  +100 XP  │
///     Play a topic
///     ╭ Algorithms    ╮ ╭ Data Structures ╮      ← whole tile plays
///     │ Easy, 10 XP   │ │ Medium, 15 XP   │
///     │ [  ▶ Play  ]  │ │ [  ▶ Play  ]    │
///     ╭ ▭ Warm up: Algorithms cards     › ╮      ← one deck to study
///     Exercises                                  ← +10 XP a blank, once
///
/// Decks is the only other tab.
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
    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]

    private var profile: UserProfile? { profiles.first }
    private var xp: Int { profile?.totalXP ?? 0 }
    private var pinned: [String] { profile?.pinnedTopicIds ?? [] }

    var body: some View {
        let stats = HomeStats(records: records, decks: decks, snapshots: snapshots)
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                header
                LevelHero(xp: xp)
                questsSection
                topicsSection(stats)
                warmUp(stats)
                BentoSection("Exercises") {
                    ExerciseTiles(topics: topics, solved: Set(profile?.solvedExerciseIds ?? []))
                }
                if showsSignInNudge {
                    signInNudge
                }
            }
            .padding([.horizontal, .bottom], CodeySpacing.md)
        }
        .codeyTabPage()
        .toolbarVisibility(.hidden, for: .navigationBar)
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

    /// The one deck to study (cards pay +5 XP for each card moved up):
    /// the session in progress, the starter deck, or a deck in the
    /// suggested topic.
    @ViewBuilder
    private func warmUp(_ stats: HomeStats) -> some View {
        let pick: (deck: FlashcardDeck, resume: Bool, title: String, detail: String)? = {
            switch upNext(stats) {
            case .resume(let deckID, let position, let total):
                return stats.deckByID[deckID].map { ($0, true, "Continue: \($0.title)", "Card \(position) of \(total), +\(XPRewards.cardMovedUp) XP a card") }
            case .startDeck(let deckID):
                return stats.deckByID[deckID].map { ($0, false, "Warm up: \($0.title)", "\($0.cardCount) cards, +\(XPRewards.cardMovedUp) XP a card") }
            case .quiz(let topicID):
                return stats.decksByTopic[topicID]?.first.map { ($0, false, "Warm up: \($0.title)", "\($0.cardCount) cards, +\(XPRewards.cardMovedUp) XP a card") }
            case .none:
                return nil
            }
        }()
        if let pick {
            Button {
                router.study = StudyRequest(deck: pick.deck, start: pick.resume ? .resume : .fresh(tierFilter: nil))
            } label: {
                PlayRow(icon: "rectangle.stack", title: pick.title, detail: pick.detail, hue: .of(topicID: pick.deck.topicId))
            }
            .buttonStyle(TilePressStyle())
            .accessibilityIdentifier("home.upNext")
        }
    }

    // MARK: Header

    private var header: some View {
        let streak = StreakCalculator.currentStreak(endingOn: .now, activity: activity)
        return TabHeader(eyebrow: HomeLogic.greeting(at: .now), title: profile?.username ?? UserProfile.defaultUsername) {
            // Always shown, 0 included (FR-37: the current streak).
            Label("\(streak)", icon: "flame")
                .font(.codeyHeadline.monospacedDigit())
                .foregroundStyle(CodeyColor.xp)
                .padding(.horizontal, CodeySpacing.md)
                .frame(height: 44)
                .background(CodeyColor.xpSoft, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(streak) day streak")
            NavigationLink {
                GroupsView()
            } label: {
                CircleIcon(systemImage: "trophy", kind: .soft)
            }
            .buttonStyle(TilePressStyle())
            .accessibilityLabel("Groups and leaderboard")
            .accessibilityIdentifier("home.groups")
            CircleIconButton(systemImage: ProfileAvatar.symbol(for: profile?.avatarId), label: "Profile", kind: .soft) {
                router.showProfile = true
            }
            .accessibilityIdentifier("home.profile")
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

    /// Topics in this week's plan get a "This week" tag on their tile.
    private var planIDs: Set<String> { Set(plannedTopics.map(\.id)) }

    // MARK: Quests (FR-32, FR-42, S41 bonuses)

    private var todayCount: Int {
        StreakCalculator.progress(of: activity.first { $0.day == DailyActivity.dayKey(for: .now) })
    }

    private var challenge: WeeklyChallenge.Status? {
        WeeklyChallenge.status(now: .now, topicIDs: topics.map(\.id), records: records)
    }

    /// Both quests open quiz setup: the daily goal on this week's first
    /// topic, the challenge on its own topic. The first unpaid one is "Up next".
    private var questsSection: some View {
        let goal = GatingConfig.standard.dailyGoal
        let dailyPaid = profile?.goalBonusDay == DailyActivity.dayKey(for: .now)
        let weeklyPaid = profile?.challengeBonusWeek == UTCWeek.key(for: .now)
        let challengeTopic = challenge.flatMap { status in topics.first { $0.id == status.topicID } }
        return BentoSection("Today's quests") {
            Button {
                router.quizSetupTopic = plannedTopics.first ?? orderedTopics.first
            } label: {
                QuestTile(
                    icon: "target",
                    title: "Answer \(goal)",
                    count: "\(min(todayCount, goal)) of \(goal) today",
                    progress: Double(min(todayCount, goal)) / Double(goal),
                    bonus: XPRewards.dailyGoalBonus,
                    isPaid: dailyPaid,
                    isNext: !dailyPaid,
                    hue: .teal
                )
            }
            .buttonStyle(TilePressStyle())
            .disabled(dailyPaid || topics.isEmpty)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily goal: \(min(todayCount, goal)) of \(goal) answers or cards, \(dailyPaid ? "bonus paid" : "plus \(XPRewards.dailyGoalBonus) XP")")
            .accessibilityAddTraits(dailyPaid ? [] : .isButton)
            .accessibilityHint(dailyPaid ? "" : "Opens quiz setup")
            .accessibilityIdentifier("play.quest.daily")
            if let challenge, let topic = challengeTopic {
                Button { router.quizSetupTopic = topic } label: {
                    QuestTile(
                        icon: "flag.checkered",
                        title: "\(WeeklyChallenge.goal) right in \(topic.title)",
                        count: "\(min(challenge.correct, WeeklyChallenge.goal)) of \(WeeklyChallenge.goal) this week",
                        progress: challenge.progress,
                        bonus: XPRewards.weeklyChallengeBonus,
                        isPaid: weeklyPaid,
                        isNext: dailyPaid && !weeklyPaid,
                        hue: .coral
                    )
                }
                .buttonStyle(TilePressStyle())
                .disabled(weeklyPaid)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Weekly challenge: \(min(challenge.correct, WeeklyChallenge.goal)) of \(WeeklyChallenge.goal) right in \(topic.title), \(weeklyPaid ? "bonus paid" : "plus \(XPRewards.weeklyChallengeBonus) XP")")
                .accessibilityAddTraits(weeklyPaid ? [] : .isButton)
                .accessibilityHint(weeklyPaid ? "" : "Opens quiz setup")
                .accessibilityIdentifier("home.challenge")
            }
        }
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

    /// This week's plan first (FR-38), then the rest, pinned first.
    private func topicsSection(_ stats: HomeStats) -> some View {
        let plan = planIDs
        let ordered = orderedTopics.filter { plan.contains($0.id) } + orderedTopics.filter { !plan.contains($0.id) }
        return BentoSection("Play a topic") {
            ForEach(ordered) { topic in
                PlayTopicTile(stats: quizStats(for: topic), inPlan: plan.contains(topic.id)) {
                    router.quizSetupTopic = topic
                }
            }
        }
    }

    /// Tier locks, accuracy over the last answers (FR-36), and retired count.
    private func quizStats(for topic: Topic) -> QuizTopicStats {
        let progress = progressRows.filter { $0.topicId == topic.id }.keyed(by: \.questionId)
        let sticky = topicProgress.first { $0.topicId == topic.id }?.unlockedTiers ?? []
        return QuizTopicStats(
            topic: topic,
            tiers: QuizProgressStore.availability(questions: topic.questions, progress: progress, sticky: sticky, xp: xp),
            accuracy: QuizProgressStore.accuracy(
                of: records.filter { $0.topicId == topic.id },
                window: GatingConfig.standard.accuracyWindow
            ),
            retired: topic.questions.filter { progress[$0.id]?.isRetired == true }.count,
            total: topic.questions.count
        )
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
