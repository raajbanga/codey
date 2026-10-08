import SwiftData
import SwiftUI

/// Home (D8, simplified r3): progress at a glance plus ONE suggestion.
///
///     Good evening                          (◎)
///     Codey Learner
///     ╭ ◔ Lv 4   1,840 XP · 160 to Lv 5  🔥 3 ╮   ← LevelCard
///     ╭ Up next: ▶ Continue Swift Closures 7/12 ╮   ← one action
///     Topics (all; pinned first)
///     ╭ ◆ Data Structures                    ╮
///     │   42% mastered · 78% accuracy         │
///     │ [▷ Practice]          [? Quiz]        │  ← deck (menu if several) / quiz setup
///     ╰───────────────────────────────────────╯
///
/// Everything else lives in its tab (Decks, Quiz); Home doesn't duplicate it.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(BackendFacade.self) private var backend
    @AppStorage("home.signInNudgeDismissed") private var nudgeDismissed = false

    @Query private var profiles: [UserProfile]
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query(filter: #Predicate<FlashcardDeck> { $0.deletedAt == nil }) private var decks: [FlashcardDeck]
    @Query(sort: [SortDescriptor(\StudyProgressSnapshot.updatedAt, order: .reverse)])
    private var snapshots: [StudyProgressSnapshot]
    @Query private var records: [QuizAnswerRecord]

    private var profile: UserProfile? { profiles.first }
    private var xp: Int { profile?.totalXP ?? 0 }
    private var pinned: [String] { profile?.pinnedTopicIds ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                header
                LevelCard(xp: xp, streak: profile?.currentStreak ?? 0)
                upNextCard
                topicsSection
                if showsSignInNudge {
                    signInNudge
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(CodeyColor.surface)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.showProfile = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.codeyTitle)
                        .foregroundStyle(CodeyColor.brand)
                }
                .accessibilityLabel("Profile")
                .accessibilityIdentifier("home.profile")
            }
        }
        .toolbarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
            Text(HomeLogic.greeting(at: .now))
                .font(.codeyCallout)
                .foregroundStyle(CodeyColor.textSecondary)
            Text(profile?.username ?? UserProfile.defaultUsername)
                .font(.codeyDisplay)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Up next

    private var upNext: HomeLogic.UpNext {
        let deckByID = decks.keyed(by: \.id)
        let resumable = snapshots.first { snapshot in
            deckByID[snapshot.deckId] != nil && snapshot.position < snapshot.cardIDs.count
        }
        return HomeLogic.upNext(
            resumable: resumable.map { ($0.deckId, $0.displayPosition, $0.cardIDs.count) },
            isNewLearner: isNewLearner,
            starterDeckID: suggestedStarterDeck?.id,
            weakestTopicID: HomeLogic.weakestTopicID(candidates: quizCandidates, accuracy: accuracyByTopic)
        )
    }

    @ViewBuilder
    private var upNextCard: some View {
        switch upNext {
        case .resume(let deckID, let position, let total):
            if let deck = deck(deckID) {
                UpNextCard(
                    eyebrow: "Continue studying",
                    title: deck.title,
                    detail: "Card \(position) of \(total)",
                    systemImage: "play.fill",
                    progress: total == 0 ? nil : Double(position - 1) / Double(total)
                ) { router.study = StudyRequest(deck: deck, start: .resume) }
            }
        case .startDeck(let deckID):
            if let deck = deck(deckID) {
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
                    detail: accuracyByTopic[topicID].map { "Your weakest topic · \($0.percentText) accuracy" } ?? "You haven't quizzed this topic yet",
                    systemImage: "questionmark.bubble.fill"
                ) { router.quizSetupTopic = topic }
            }
        case .none:
            EmptyView()
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

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            Text("Topics")
                .font(.codeyTitle)
                .accessibilityAddTraits(.isHeader)
            ForEach(orderedTopics) { topic in
                TopicCard(
                    topic: topic,
                    isPinned: pinned.contains(topic.id),
                    decks: decks(for: topic),
                    snapshotDeckIDs: Set(snapshots.map(\.deckId)),
                    accuracy: accuracyByTopic[topic.id],
                    practice: { deck, resume in
                        router.study = StudyRequest(deck: deck, start: resume ? .resume : .fresh(tierFilter: nil))
                    },
                    quiz: { router.quizSetupTopic = topic }
                )
            }
        }
    }

    /// The topic's visible decks: starter decks first, then the user's, by title.
    private func decks(for topic: Topic) -> [FlashcardDeck] {
        decks
            .filter { $0.topicId == topic.id && !$0.isHidden && $0.cardCount > 0 }
            .sorted { lhs, rhs in
                if lhs.origin != rhs.origin { return lhs.origin == .starter }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    // MARK: Data

    private var accuracyByTopic: [String: Double] {
        Dictionary(grouping: records, by: \.topicId).compactMapValues {
            QuizProgressStore.accuracy(of: $0, window: GatingConfig.standard.accuracyWindow)
        }
    }

    /// No quiz answers and no studied cards yet.
    private var isNewLearner: Bool {
        records.isEmpty && !decks.contains { deck in deck.activeCards.contains { $0.lastReviewedAt != nil } }
    }

    /// The starter deck for the first pinned topic (or any starter deck).
    private var suggestedStarterDeck: FlashcardDeck? {
        let starters = decks.filter { $0.origin == .starter && !$0.isHidden }
        for topicID in pinned {
            if let deck = starters.first(where: { $0.topicId == topicID }) { return deck }
        }
        return starters.min { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func deck(_ id: UUID) -> FlashcardDeck? {
        decks.first { $0.id == id }
    }

    // MARK: Sign-in nudge

    /// Only when sign-in is possible in this build and the user is a guest.
    private var showsSignInNudge: Bool {
        backend.isSignInAvailable && backend.currentUser == nil && !nudgeDismissed
    }

    private var signInNudge: some View {
        CodeyCard(tint: CodeyColor.brand) {
            HStack(alignment: .top, spacing: CodeySpacing.sm) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.codeyTitle)
                    .foregroundStyle(CodeyColor.brand)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                    Text("Back up your decks")
                        .font(.codeyHeadline)
                    Text("Sign in from your profile to sync decks and XP across devices.")
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation(CodeyMotion.snappy) { nudgeDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.codeyCallout.weight(.semibold))
                        .foregroundStyle(CodeyColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .onTapGesture { router.showProfile = true }
    }
}

// MARK: - Components

/// Level ring + XP + "n XP to Level N+1" + streak chip.
private struct LevelCard: View {
    let xp: Int
    let streak: Int

    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 64

    private var level: Int { LevelCalculator.level(forXP: xp) }

    var body: some View {
        CodeyCard {
            HStack(spacing: CodeySpacing.md) {
                ProgressRing(value: LevelCalculator.progressFraction(xp), lineWidth: 7) {
                    VStack(spacing: 0) {
                        Text("Lv")
                            .font(.codeyCaption.weight(.semibold))
                            .foregroundStyle(CodeyColor.textSecondary)
                        Text(level, format: .number)
                            .font(.codeyNumericSmall)
                            .contentTransition(.numericText(value: Double(level)))
                    }
                }
                .frame(width: ringSize, height: ringSize)

                VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: CodeySpacing.xs) {
                        Text(xp, format: .number)
                            .font(.codeyNumeric)
                            .contentTransition(.numericText(value: Double(xp)))
                        Text("XP")
                            .font(.codeyCaption.weight(.semibold))
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                    Text("\(LevelCalculator.xpToNextLevel(xp)) XP to Level \(level + 1)")
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                if streak > 0 {
                    CodeyChip("\(streak)", systemImage: "flame.fill", variant: .warning)
                        .accessibilityLabel("\(streak) day streak")
                }
            }
        }
        .codeyAnimation(CodeyMotion.snappy, value: xp)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(level), \(xp) XP, \(LevelCalculator.xpToNextLevel(xp)) to the next level")
    }
}

/// The one tappable suggestion on Home. The whole card is the button.
private struct UpNextCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    var progress: Double?
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 48

    var body: some View {
        Button(action: action) {
            HStack(spacing: CodeySpacing.md) {
                Group {
                    if let progress {
                        ProgressRing(value: progress, lineWidth: 4) {
                            Image(systemName: systemImage)
                                .font(.codeyHeadline)
                                .foregroundStyle(CodeyColor.brand)
                        }
                    } else {
                        IconTile(systemName: systemImage, size: iconSize)
                    }
                }
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                    Text(eyebrow.uppercased())
                        .font(.codeyCaption.weight(.semibold))
                        .foregroundStyle(CodeyColor.brand)
                    Text(title)
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.codeyCallout.weight(.semibold))
                    .foregroundStyle(CodeyColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(CodeySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.lg))
            .overlay {
                RoundedRectangle.codey(CodeyRadius.lg)
                    .strokeBorder(CodeyColor.brand.opacity(0.35), lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eyebrow): \(title). \(detail)")
        .accessibilityIdentifier("home.upNext")
    }
}

/// One topic on Home: icon, title, mastery + accuracy, and the two ways to
/// practice it: Practice (flashcards) and Quiz.
private struct TopicCard: View {
    let topic: Topic
    let isPinned: Bool
    let decks: [FlashcardDeck]
    let snapshotDeckIDs: Set<UUID>
    let accuracy: Double?
    /// (deck, resume?)
    let practice: (FlashcardDeck, Bool) -> Void
    let quiz: () -> Void

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 52

    var body: some View {
        CodeyCard {
            VStack(alignment: .leading, spacing: CodeySpacing.md) {
                HStack(alignment: .top, spacing: CodeySpacing.md) {
                    IconTile(systemName: topic.iconName, size: iconSize)
                    VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                        HStack(spacing: CodeySpacing.xs) {
                            Text(topic.title)
                                .font(.codeyTitle)
                                .foregroundStyle(CodeyColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.codeyCaption)
                                    .foregroundStyle(CodeyColor.textSecondary)
                                    .accessibilityLabel("Pinned")
                            }
                        }
                        Text(statsLine)
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                if !decks.isEmpty {
                    ProgressBar(value: masteryRate)
                        .accessibilityLabel("Flashcard mastery")
                }
                HStack(spacing: CodeySpacing.sm) {
                    practiceButton
                    CodeyButton("Quiz", systemImage: "questionmark.bubble.fill", fullWidth: true, action: quiz)
                        .accessibilityIdentifier("home.topic.\(topic.title).quiz")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// One deck → a button. Several → a menu of decks. None → disabled.
    @ViewBuilder
    private var practiceButton: some View {
        if decks.count > 1 {
            Menu {
                ForEach(decks) { deck in
                    Button {
                        practice(deck, snapshotDeckIDs.contains(deck.id))
                    } label: {
                        Label(
                            snapshotDeckIDs.contains(deck.id) ? "\(deck.title) (continue)" : deck.title,
                            systemImage: deck.origin == .starter ? "sparkles" : "rectangle.stack"
                        )
                    }
                }
            } label: {
                practiceLabel
            }
            .modifier(PracticeStyle())
            .accessibilityHint("Choose a deck to study")
            .accessibilityIdentifier("home.topic.\(topic.title).practice")
        } else {
            Button {
                if let deck = decks.first { practice(deck, snapshotDeckIDs.contains(deck.id)) }
            } label: {
                practiceLabel
            }
            .modifier(PracticeStyle())
            .disabled(decks.isEmpty)
            .accessibilityIdentifier("home.topic.\(topic.title).practice")
        }
    }

    private var practiceLabel: some View {
        Label("Practice", systemImage: "rectangle.on.rectangle.angled")
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
    }

    private struct PracticeStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(CodeyColor.brand)
        }
    }

    private var masteryRate: Double {
        let cards = decks.flatMap(\.activeCards)
        guard !cards.isEmpty else { return 0 }
        return Double(cards.filter(\.isMastered).count) / Double(cards.count)
    }

    private var statsLine: String {
        var parts: [String] = []
        if !decks.isEmpty { parts.append("\(masteryRate.percentText) mastered") }
        parts.append(accuracy.map { "\($0.percentText) accuracy" } ?? "No quizzes yet")
        return parts.joined(separator: " · ")
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
