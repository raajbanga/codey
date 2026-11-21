import SwiftData
import SwiftUI

/// Quiz setup, shown in a FloatingPanel (S40; was a medium-detent sheet):
/// Mixed vs one unlocked tier (FR-29), how many questions, the next locked
/// tier's reason, Start. When every unlocked question is
/// retired: "Topic mastered!" with a no-XP review of retired questions.
struct QuizSetupView: View {
    let topic: Topic
    let start: (QuizMode) -> Void

    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]
    @Query private var profiles: [UserProfile]
    @Query private var records: [QuizAnswerRecord]
    /// .mixed or .tier(_); review has its own button.
    @State private var choice: QuizMode = .mixed

    init(topic: Topic, start: @escaping (QuizMode) -> Void) {
        self.topic = topic
        self.start = start
        let id = topic.id
        _progressRows = Query(filter: #Predicate<QuestionProgress> { $0.topicId == id })
        _topicProgress = Query(filter: #Predicate<TopicProgress> { $0.topicId == id })
        _records = Query(filter: #Predicate<QuizAnswerRecord> { $0.topicId == id })
    }

    private var config: GatingConfig { .standard }
    private var hue: CodeyColor.TopicHue { .of(topicID: topic.id) }
    private var bestTier: Difficulty { tiers.last(where: \.isUnlocked)?.difficulty ?? .easy }
    private var progress: [String: QuestionProgress] { progressRows.keyed(by: \.questionId) }
    private var xp: Int { profiles.first?.totalXP ?? 0 }
    private var tiers: [TierAvailability] {
        QuizProgressStore.availability(
            questions: topic.questions,
            progress: progress,
            sticky: topicProgress.first?.unlockedTiers ?? [],
            xp: xp,
            config: config
        )
    }
    private var unlocked: Set<Difficulty> { Set(tiers.filter(\.isUnlocked).map(\.difficulty)) }
    private var candidates: [PoolCandidate] {
        QuizProgressStore.candidates(questions: topic.questions, progress: progress, now: .now, config: config)
    }
    private var activeCount: Int {
        candidates.filter { candidate in
            guard candidate.isActive, unlocked.contains(candidate.difficulty) else { return false }
            if case .tier(let tier) = choice { return candidate.difficulty == tier }
            return true
        }.count
    }
    private var retiredCount: Int {
        candidates.filter { !$0.isActive && unlocked.contains($0.difficulty) }.count
    }
    private var accuracy: Double? {
        QuizProgressStore.accuracy(of: records, window: config.accuracyWindow)
    }
    private var isMastered: Bool {
        QuestionPool.activeIDs(candidates, unlocked: unlocked).isEmpty
    }

    var body: some View {
        // Gaps match the padding (Nov 15). A locked tier is one line under
        // the choices.
        VStack(alignment: .leading, spacing: CodeySpacing.lg) {
            header
            if isMastered {
                masteredState
            } else {
                picker
            }
            startButton
        }
        .codeyPanelPadding()
        .onChange(of: unlocked) { _, open in
            if case .tier(let tier) = choice, !open.contains(tier) { choice = .mixed }
        }
    }

    /// The topic in its pastel, like every page's hero (Nov 15): what a
    /// question pays as a tag, and the same bar as the topic's tile on
    /// Play (accuracy over the last answers, FR-36).
    /// No ✕: the panel is swiped away (or tapped outside, or VoiceOver's
    /// escape gesture).
    private var header: some View {
        HeroCard(
            title: topic.title,
            subtitle: isMastered ? nil : readyText,
            icon: topic.iconName,
            hue: hue,
            progress: accuracy ?? 0,
            caption: isMastered ? "Every unlocked question retired" : accuracy.map { "\($0.percentText) correct lately" } ?? "No answers yet"
        ) {
            CodeyChip(xp: XPPolicy.base(bestTier))
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.md) {
            ChoiceChips(
                "Questions",
                selection: $choice,
                options: [(.mixed, "Mixed")] + Difficulty.allCases.filter(unlocked.contains).map { (.tier($0), $0.style.label) },
                fills: true
            )
            .accessibilityIdentifier("quizSetup.mode")
            .accessibilityHint(choice == .mixed ? "Mostly your top tier, with some review" : "\(choiceLabel) questions only")
            TierLockNote(tiers: tiers)
        }
    }

    private var masteredState: some View {
        CodeyCard(tint: CodeyColor.success) {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                Label("Topic mastered!", icon: "checkmark.seal.fill")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.success)
                Text(masteredMessage)
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
        }
    }

    private var masteredMessage: String {
        var message = "You've retired every question you've unlocked. Retired questions come back for review after \(config.reviewAfterDays) days."
        if let locked = tiers.first(where: { !$0.isUnlocked }), let reason = locked.lockReason {
            message += " \(locked.difficulty.style.label) is next: \(reason)."
        }
        return message
    }

    private var startButton: some View {
        Group {
            if isMastered {
                CodeyButton("Review Retired Questions", systemImage: "arrow.counterclockwise", kind: .hue(hue), fullWidth: true) {
                    start(.review)
                }
                .disabled(retiredCount == 0)
                .accessibilityHint("Practice only. No XP.")
            } else {
                CodeyButton("Start", systemImage: "play", kind: .hue(hue), fullWidth: true) {
                    start(choice)
                }
                .disabled(activeCount == 0)
                .accessibilityIdentifier("quizSetup.start")
            }
        }
    }

    private var choiceLabel: String {
        if case .tier(let tier) = choice { return tier.style.label }
        return "Mixed"
    }

    /// "7 of 10 questions ready", or "10 questions" when the quiz is full.
    private var readyText: String {
        let size = config.quizSize
        let tier = choice == .mixed ? "" : "\(choiceLabel) "
        return activeCount >= size ? "\(size) \(tier)questions" : "\(activeCount) of \(size) \(tier)questions ready"
    }
}

#Preview("Setup") {
    let container = ModelContainerFactory.makePreview()
    let topic = try! container.mainContext.fetch(FetchDescriptor<Topic>()).first!
    return Color.clear
        .floatingPanel(item: .constant(Optional(topic))) { topic in
            QuizSetupView(topic: topic) { _ in }
        }
        .modelContainer(container)
}
