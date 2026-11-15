import SwiftData
import SwiftUI
import os

/// First-launch onboarding (D16), shown once as a full-screen cover:
/// 1. Welcome  2. Pick topics (≥ 1, pinned on Home + Decks)  3. Sync (Skip).
struct OnboardingView: View {
    static let completedKey = "hasCompletedOnboarding"

    let finish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BackendFacade.self) private var backend
    @Query(sort: \Topic.title) private var topics: [Topic]

    @State private var step = Step.welcome
    @State private var picked: [String] = []
    @State private var goingForward = true

    enum Step: Int, CaseIterable {
        case welcome, topics, sync
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                switch step {
                case .welcome: WelcomeStep().transition(stepTransition)
                case .topics: TopicPickStep(topics: topics, picked: $picked).transition(stepTransition)
                case .sync: SyncStep(isSignInAvailable: backend.isSignInAvailable, authState: backend.authState).transition(stepTransition)
                }
            }
            .frame(maxHeight: .infinity)
            bottomBar
        }
        .codeyPaperBackground()
        .interactiveDismissDisabled()
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            if step != .welcome {
                CircleIconButton(systemImage: "chevron.left", label: "Back") {
                    move(to: Step(rawValue: step.rawValue - 1) ?? .welcome)
                }
                .accessibilityIdentifier("onboarding.back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            PageDots(count: Step.allCases.count, index: step.rawValue)
            Spacer()
            // Balances the Back button so the dots stay centered.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, CodeySpacing.md)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: CodeySpacing.sm) {
            switch step {
            case .welcome:
                CodeyButton("Get Started", kind: .primary, fullWidth: true) { move(to: .topics) }
                    .accessibilityIdentifier("onboarding.continue")
            case .topics:
                CodeyButton(
                    picked.isEmpty ? "Pick at least one topic" : "Continue",
                    kind: .primary,
                    fullWidth: true
                ) { move(to: .sync) }
                .disabled(picked.isEmpty)
                .accessibilityIdentifier("onboarding.continue")
            case .sync:
                if backend.isSignInAvailable {
                    CodeyButton("Sign in with Google", systemImage: "person.badge.key", kind: .secondary, fullWidth: true) {
                        Task {
                            await backend.signInWithGoogle()
                            if backend.currentUser != nil { complete() }
                        }
                    }
                    .disabled(backend.authState == .signingIn)
                    .accessibilityIdentifier("onboarding.signIn")
                }
                CodeyButton("Skip for Now", kind: .primary, fullWidth: true) { complete() }
                    .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.bottom, CodeySpacing.md)
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func move(to next: Step) {
        goingForward = next.rawValue > step.rawValue
        withCodeyAnimation(CodeyMotion.smooth, reduceMotion: reduceMotion) { step = next }
    }

    /// Saves the picked topics and closes onboarding.
    private func complete() {
        let profile = DataSeeder.ensureProfile(context: modelContext)
        profile.pinnedTopicIds = picked
        do {
            try modelContext.save()
        } catch {
            Logger.settings.error("Saving onboarding picks failed: \(String(describing: error))")
        }
        finish()
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    @ScaledMetric(relativeTo: .largeTitle) private var glyph: CGFloat = 96

    var body: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.xl) {
                AppGlyph(size: glyph)
                    .padding(.top, CodeySpacing.xl)
                VStack(spacing: CodeySpacing.sm) {
                    Text("Learn CS with flashcards & quizzes")
                        .font(.codeyDisplay)
                        .multilineTextAlignment(.center)
                    Text("Short, focused practice that adapts as you improve.")
                        .font(.codeyCallout)
                        .foregroundStyle(CodeyColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                BentoGrid {
                    GameTile(icon: "rectangle.on.rectangle.angled", title: "Study decks",
                             detail: "Flip cards, rate what you knew.", hue: .teal)
                    GameTile(icon: "questionmark.bubble", title: "Take quizzes",
                             detail: "Earn XP and keep a streak.", hue: .sky)
                    GameTile(icon: "lock.open", title: "Unlock harder tiers",
                             detail: "Master Easy to open Medium, then Hard.", hue: .coral)
                }
            }
            .padding(CodeySpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct TopicPickStep: View {
    let topics: [Topic]
    @Binding var picked: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                    Text("What do you want to study?")
                        .font(.codeyDisplay)
                    Text("We'll pin these on Home and put their starter decks first. You can change this later in your profile.")
                        .font(.codeyCallout)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                BentoGrid {
                    ForEach(topics) { topic in
                        TopicTile(topic: topic, isSelected: picked.contains(topic.id)) {
                            if let index = picked.firstIndex(of: topic.id) {
                                picked.remove(at: index)
                            } else {
                                picked.append(topic.id)
                            }
                        }
                    }
                }
            }
            .padding(CodeySpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// "How data moves: IP, TCP/UDP, HTTP, DNS, and TLS." → "IP, TCP/UDP,
    /// HTTP": the first three subjects, so it fits a half-width tile.
    static func short(_ summary: String) -> String {
        var text = summary
        if let colon = text.firstIndex(of: ":") { text = String(text[text.index(after: colon)...]) }
        text = text.replacingOccurrences(of: ", and ", with: ", ").replacingOccurrences(of: " and ", with: ", ")
        let items = text.trimmingCharacters(in: CharacterSet(charactersIn: " .")).components(separatedBy: ", ")
        return items.prefix(3).joined(separator: ", ")
    }
}

extension TopicPickStep {
    /// A topic as a GameTile in its color: on its pastel once picked, on
    /// the plain note before.
    private struct TopicTile: View {
        let topic: Topic
        let isSelected: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                GameTile(
                    icon: topic.iconName,
                    title: topic.title,
                    detail: TopicPickStep.short(topic.summary),
                    hue: .of(topicID: topic.id),
                    filled: isSelected,
                    status: {
                        if isSelected {
                            CodeyChip("Picked", systemImage: "checkmark", variant: .outline(CodeyColor.TopicHue.of(topicID: topic.id).ink))
                        }
                    }
                )
            }
            .buttonStyle(TilePressStyle())
            .sensoryFeedback(.selection, trigger: isSelected)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("onboarding.topic.\(topic.title)")
        }
    }
}

private struct SyncStep: View {
    let isSignInAvailable: Bool
    let authState: AuthState

    private let hue = CodeyColor.TopicHue.slate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                Text("Back up & sync")
                    .font(.codeyDisplay)
                VStack(alignment: .leading, spacing: CodeySpacing.md) {
                    IconTile(systemName: "icloud.and.arrow.up", size: 64, radius: CodeyRadius.md, ink: .white, tile: hue.fill)
                    Text(isSignInAvailable
                         ? "Sign in with Google to back up your decks and XP and sync them across devices. You can also skip and sign in later from your profile."
                         : "Codey works fully offline. Everything is saved on this device.")
                        .font(.codeyCallout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(hue.ink)
                .padding(CodeySpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(hue.soft, in: .codey(CodeyRadius.lg))
                .environment(\.colorScheme, .light)
                BentoGrid {
                    GameTile(icon: "rectangle.stack", title: "Decks", detail: "Every card you write", hue: .teal, filled: false)
                    GameTile(icon: "star", title: "XP & level", detail: "Shared with your groups", hue: .sand, filled: false)
                }
                if case .error(let message) = authState {
                    Text(message)
                        .font(.codeyCallout)
                        .foregroundStyle(CodeyColor.danger)
                }
            }
            .padding(CodeySpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Step progress: the current step a wider capsule.
private struct PageDots: View {
    let count: Int
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: CodeySpacing.xs) {
            ForEach(0..<count, id: \.self) { dot in
                Capsule()
                    .fill(dot == index ? CodeyColor.TopicHue.slate.fill : CodeyColor.paperDot)
                    .frame(width: dot == index ? 28 : 8, height: 8)
            }
        }
        .codeyAnimation(CodeyMotion.snappy, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    OnboardingView {}
        .modelContainer(container)
        .environment(BackendFacade.localOnly(context: container.mainContext))
}
