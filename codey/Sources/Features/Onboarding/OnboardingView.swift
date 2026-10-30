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
                Button {
                    move(to: Step(rawValue: step.rawValue - 1) ?? .welcome)
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.codeyCallout.weight(.semibold))
                }
                .tint(CodeyColor.brand)
                .accessibilityIdentifier("onboarding.back")
            }
            Spacer()
            PageDots(count: Step.allCases.count, index: step.rawValue)
            Spacer()
            // Balances the Back button so the dots stay centered.
            Label("Back", systemImage: "chevron.left")
                .font(.codeyCallout.weight(.semibold))
                .hidden()
                .accessibilityHidden(true)
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
                VStack(alignment: .leading, spacing: CodeySpacing.md) {
                    Feature(symbol: "rectangle.on.rectangle.angled", title: "Study decks", detail: "Flip cards and swipe to rate how well you knew them.")
                    Feature(symbol: "questionmark.bubble.fill", title: "Take quizzes", detail: "Earn XP and keep a streak going.")
                    Feature(symbol: "lock.open.fill", title: "Unlock harder tiers", detail: "Master Easy to open Medium, then Hard.")
                }
            }
            .padding(CodeySpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private struct Feature: View {
        let symbol: String
        let title: String
        let detail: String

        var body: some View {
            HStack(alignment: .top, spacing: CodeySpacing.md) {
                Image(systemName: symbol)
                    .font(.codeyTitle)
                    .foregroundStyle(CodeyColor.brand)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                    Text(title).font(.codeyHeadline)
                    Text(detail)
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: CodeySpacing.sm)], spacing: CodeySpacing.sm) {
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

    private struct TopicTile: View {
        let topic: Topic
        let isSelected: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    HStack {
                        Image(systemName: topic.iconName)
                            .font(.codeyTitle)
                            .foregroundStyle(CodeyColor.brand)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.codeyTitle)
                            .foregroundStyle(isSelected ? CodeyColor.brand : CodeyColor.textSecondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Text(topic.title)
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(topic.summary)
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .padding(CodeySpacing.md)
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                .codeyNote(
                    fill: isSelected ? CodeyColor.brandSoft : CodeyColor.surfaceRaised,
                    edge: isSelected ? CodeyColor.brand : nil
                )
                .contentShape(.rect(cornerRadius: CodeyRadius.lg))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isSelected)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("onboarding.topic.\(topic.title)")
        }
    }
}

private struct SyncStep: View {
    let isSignInAvailable: Bool
    let authState: AuthState

    var body: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.lg) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.codeyDisplay)
                    .imageScale(.large)
                    .foregroundStyle(CodeyColor.brand)
                    .padding(.top, CodeySpacing.xl)
                    .accessibilityHidden(true)
                Text("Back up & sync")
                    .font(.codeyDisplay)
                    .multilineTextAlignment(.center)
                Text(isSignInAvailable
                     ? "Sign in with Google to back up your decks and XP and sync them across devices. You can also skip and sign in later from your profile."
                     : "Codey works fully offline. Everything is saved on this device.")
                    .font(.codeyCallout)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .multilineTextAlignment(.center)
                if case .error(let message) = authState {
                    Text(message)
                        .font(.codeyCallout)
                        .foregroundStyle(CodeyColor.danger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(CodeySpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Dots for the current onboarding step.
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: CodeySpacing.xs) {
            ForEach(0..<count, id: \.self) { dot in
                Circle()
                    .fill(dot == index ? CodeyColor.brand : CodeyColor.fillNeutral)
                    .frame(width: 8, height: 8)
            }
        }
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
