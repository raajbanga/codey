import SwiftData
import SwiftUI

/// Home (D8, simplified r3): progress at a glance plus ONE suggestion.
///
///     Good evening                          (◎)
///     Codey Learner
///     ╭ ◔ Lv 4   1,840 XP · 160 to Lv 5  🔥 3 ╮   ← LevelCard
///     ╭ Up next: ▶ Continue Swift Closures 7/12 ╮   ← one action
///     Your topics
///     ◆ Data Structures                 78%  ›   ← → quiz setup
///
/// Everything else lives in its tab (Decks, Quiz); Home doesn't duplicate it.
struct HomeView: View {
    @Environment(Router.self) private var router
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
        let deckByID = Dictionary(decks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let resumable = snapshots.first { snapshot in
            deckByID[snapshot.deckId] != nil && snapshot.position < snapshot.cardIDs.count
        }
        return HomeLogic.upNext(
            resumable: resumable.map { ($0.deckId, $0.displayPosition, $0.cardIDs.count) },
            isNewLearner: isNewLearner,
            starterDeckID: suggestedStarterDeck?.id,
            weakestTopicID: HomeLogic.weakestTopicID(candidates: yourTopics.map(\.id), accuracy: accuracyByTopic)
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
                    detail: accuracyByTopic[topicID].map { "Your weakest topic · \(percent($0)) accuracy" } ?? "You haven't quizzed this topic yet",
                    systemImage: "questionmark.bubble.fill"
                ) { router.quizSetupTopic = topic }
            }
        case .none:
            EmptyView()
        }
    }

    // MARK: Your topics

    /// Pinned topics (pin order), or every topic if none are pinned.
    private var yourTopics: [Topic] {
        let byID = Dictionary(topics.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let pinnedTopics = pinned.compactMap { byID[$0] }
        return pinnedTopics.isEmpty ? topics : pinnedTopics
    }

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            Text("Your topics")
                .font(.codeyTitle)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(yourTopics.enumerated()), id: \.element.id) { index, topic in
                    if index > 0 { Divider().padding(.leading, CodeySpacing.xxl) }
                    Button {
                        router.quizSetupTopic = topic
                    } label: {
                        TopicRow(topic: topic, accuracy: accuracyByTopic[topic.id])
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.lg))
        }
    }

    // MARK: Data

    private var accuracyByTopic: [String: Double] {
        let window = GatingConfig.standard.accuracyWindow
        var result: [String: Double] = [:]
        for (topicID, rows) in Dictionary(grouping: records, by: \.topicId) {
            result[topicID] = QuizProgressStore.accuracy(of: rows, window: window)
        }
        return result
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

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    // MARK: Sign-in nudge

    /// Only once sign-in exists (Stage 9 needs backend keys).
    private var showsSignInNudge: Bool {
        AppConfig.current.isBackendConfigured && !nudgeDismissed
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
                        Image(systemName: systemImage)
                            .font(.codeyTitle)
                            .foregroundStyle(CodeyColor.brand)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(CodeyColor.brandSoft, in: .codey(CodeyRadius.md))
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

/// Compact topic row: symbol, title, accuracy, chevron.
private struct TopicRow: View {
    let topic: Topic
    let accuracy: Double?

    var body: some View {
        HStack(spacing: CodeySpacing.md) {
            Image(systemName: topic.iconName)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.brand)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(topic.title)
                .font(.codeyBody)
                .foregroundStyle(CodeyColor.textPrimary)
            Spacer(minLength: CodeySpacing.xs)
            Text(accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                .font(.codeyNumericSmall)
                .foregroundStyle(accuracy == nil ? CodeyColor.textSecondary : CodeyColor.textPrimary)
            Image(systemName: "chevron.right")
                .font(.codeyCaption.weight(.semibold))
                .foregroundStyle(CodeyColor.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.vertical, CodeySpacing.sm + CodeySpacing.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(topic.title), \(accuracy.map { "\(Int(($0 * 100).rounded())) percent accuracy" } ?? "no answers yet")")
        .accessibilityHint("Opens quiz setup")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
    .modelContainer(ModelContainerFactory.makePreview())
}
