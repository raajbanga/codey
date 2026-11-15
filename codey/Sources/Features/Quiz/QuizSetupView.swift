import SwiftData
import SwiftUI

/// Quiz setup, shown in a FloatingPanel (S40; was a medium-detent sheet):
/// tier locks with reasons, Mixed vs one tier (FR-29), how many questions,
/// Start. When every unlocked question is
/// retired: "Topic mastered!" with a no-XP review of retired questions.
struct QuizSetupView: View {
    let topic: Topic
    let start: (QuizMode) -> Void

    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]
    @Query private var profiles: [UserProfile]
    @Environment(\.dismissPanel) private var dismissPanel
    /// .mixed or .tier(_); review has its own button.
    @State private var choice: QuizMode = .mixed

    init(topic: Topic, start: @escaping (QuizMode) -> Void) {
        self.topic = topic
        self.start = start
        let id = topic.id
        _progressRows = Query(filter: #Predicate<QuestionProgress> { $0.topicId == id })
        _topicProgress = Query(filter: #Predicate<TopicProgress> { $0.topicId == id })
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
    private var isMastered: Bool {
        QuestionPool.activeIDs(candidates, unlocked: unlocked).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.lg) {
            header
            TierChipRow(tiers: tiers)
            if isMastered {
                masteredState
            } else {
                picker
            }
            startButton
        }
        .padding(CodeySpacing.md)
        .onChange(of: unlocked) { _, open in
            if case .tier(let tier) = choice, !open.contains(tier) { choice = .mixed }
        }
    }

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 44

    private var header: some View {
        HStack(alignment: .center, spacing: CodeySpacing.md) {
            // The topic in its own color, as on its Play tile (S41).
            IconTile(systemName: topic.iconName, size: iconSize, radius: CodeyRadius.sm, ink: hue.ink, tile: hue.soft)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(topic.title)
                    .font(.codeyTitle.weight(.semibold))
                    .foregroundStyle(CodeyColor.textPrimary)
                Text("Up to \(XPPolicy.base(bestTier)) XP a question")
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            CloseButton(label: "Close quiz setup") { dismissPanel() }
                .accessibilityIdentifier("quizSetup.close")
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            ChoiceChips(
                "Questions",
                selection: $choice,
                options: [(.mixed, "Mixed")] + Difficulty.allCases.filter(unlocked.contains).map { (.tier($0), $0.style.label) },
                fills: true
            )
            .accessibilityIdentifier("quizSetup.mode")

            Text(choice == .mixed
                 ? "\(countText), mostly your top tier with some review."
                 : "\(countText), \(choiceLabel) only.")
                .font(.codeySubheadline)
                .foregroundStyle(CodeyColor.textSecondary)
        }
    }

    private var masteredState: some View {
        CodeyCard(tint: CodeyColor.success) {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                Label("Topic mastered!", systemImage: "checkmark.seal.fill")
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

    private var countText: String {
        let size = config.quizSize
        return activeCount >= size ? size.counted("question") : "\(activeCount.counted("question")) available"
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
