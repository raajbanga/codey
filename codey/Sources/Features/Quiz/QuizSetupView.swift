import SwiftData
import SwiftUI

/// Pre-quiz sheet (medium detent): tier locks with reasons, Mixed vs one
/// tier (FR-29), how many questions, Start. When every unlocked question is
/// retired: "Topic mastered!" with a no-XP review of retired questions.
struct QuizSetupView: View {
    let topic: Topic
    let start: (QuizMode) -> Void

    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]
    @Query private var profiles: [UserProfile]
    @State private var choice: Choice = .mixed

    enum Choice: Hashable {
        case mixed
        case tier(Difficulty)

        var mode: QuizMode {
            switch self {
            case .mixed: .mixed
            case .tier(let tier): .tier(tier)
            }
        }
    }

    init(topic: Topic, start: @escaping (QuizMode) -> Void) {
        self.topic = topic
        self.start = start
        let id = topic.id
        _progressRows = Query(filter: #Predicate<QuestionProgress> { $0.topicId == id })
        _topicProgress = Query(filter: #Predicate<TopicProgress> { $0.topicId == id })
    }

    private var config: GatingConfig { .standard }
    private var progress: [String: QuestionProgress] {
        Dictionary(progressRows.map { ($0.questionId, $0) }, uniquingKeysWith: { first, _ in first })
    }
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                    header
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Tiers")
                            .font(.codeyHeadline)
                        TierChipRow(tiers: tiers)
                    }
                    if isMastered {
                        masteredState
                    } else {
                        picker
                    }
                }
                .padding(CodeySpacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(CodeyColor.surface)
            .safeAreaInset(edge: .bottom) { startButton }
            .navigationTitle("Quiz Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: unlocked) { _, open in
            if case .tier(let tier) = choice, !open.contains(tier) { choice = .mixed }
        }
    }

    private var header: some View {
        HStack(spacing: CodeySpacing.md) {
            Image(systemName: topic.iconName)
                .font(.codeyTitle)
                .foregroundStyle(CodeyColor.brand)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(topic.title)
                    .font(.codeyTitle)
                Text(topic.summary)
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            Picker("Questions", selection: $choice) {
                Text("Mixed").tag(Choice.mixed)
                ForEach(Difficulty.allCases.filter(unlocked.contains), id: \.self) { tier in
                    Text(tier.style.label).tag(Choice.tier(tier))
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("quizSetup.mode")

            Text(choice == .mixed
                 ? "Mixed (recommended): mostly your highest unlocked tier, plus some review of lower tiers."
                 : "Only \(choiceLabel) questions.")
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)

            Label(countText, systemImage: "number")
                .font(.codeyCallout)
                .foregroundStyle(CodeyColor.textPrimary)
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
                CodeyButton("Review Retired Questions", systemImage: "arrow.counterclockwise", kind: .glassPrimary, fullWidth: true) {
                    start(.review)
                }
                .disabled(retiredCount == 0)
                .accessibilityHint("Practice only. No XP.")
            } else {
                CodeyButton("Start", systemImage: "play.fill", kind: .glassPrimary, fullWidth: true) {
                    start(choice.mode)
                }
                .disabled(activeCount == 0)
                .accessibilityIdentifier("quizSetup.start")
            }
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.bottom, CodeySpacing.sm)
    }

    private var choiceLabel: String {
        if case .tier(let tier) = choice { return tier.style.label }
        return "Mixed"
    }

    private var countText: String {
        let size = config.quizSize
        if activeCount >= size { return "\(size) questions" }
        return activeCount == 1 ? "1 question available" : "\(activeCount) questions available"
    }
}

#Preview("Setup") {
    let container = ModelContainerFactory.makePreview()
    let topic = try! container.mainContext.fetch(FetchDescriptor<Topic>()).first!
    return Color.clear.sheet(isPresented: .constant(true)) {
        QuizSetupView(topic: topic) { _ in }
    }
    .modelContainer(container)
}
