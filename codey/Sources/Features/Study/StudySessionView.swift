import SwiftData
import SwiftUI

/// What to study, for `.fullScreenCover(item:)`.
struct StudyRequest: Identifiable, Equatable {
    let deck: FlashcardDeck
    let start: StudySessionViewModel.Start

    var id: UUID { deck.id }
}

/// Focus-mode study session (D8, D14, UC-04). Presented as a
/// .fullScreenCover so no tab bar or accessory covers the controls.
///
///     ✕        ━━━━━━━━━──────  3 / 12 · +1 repeat
///     ╭ card (tap / Space to flip) ╮
///     │                    ●●○○○  │   ← mastery dots (S19)
///      ← Again  ↓ Hard  ↑ Easy  Good →   ← swipe to rate (hint only)
///
/// Rating is swipe-only (D14 revised): no floating buttons. Keyboard 1–4
/// and VoiceOver actions on the card cover non-gesture use.
/// Builds the session's view model once. SwiftUI can re-run a view's init
/// whenever its parent updates (e.g. while the cover is dismissed), and a
/// view model built there starts a fresh session, which deletes the saved
/// snapshot that "Continue" relies on.
struct StudySessionHost: View {
    let request: StudyRequest
    let context: ModelContext

    @State private var viewModel: StudySessionViewModel?

    var body: some View {
        if let viewModel {
            StudySessionView(viewModel: viewModel)
        } else {
            Color.clear.onAppear {
                viewModel = StudySessionViewModel(deck: request.deck, start: request.start, context: context)
            }
        }
    }
}

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: StudySessionViewModel

    @State private var drag: CGSize = .zero
    @State private var isCommitting = false
    @State private var masteredBadge: StudyCardView.MasteredBadge?
    @State private var scoreChange: StudyCardView.ScoreChange?
    @State private var feedbackEvent: FeedbackEvent?

    private static let swipeThreshold: CGFloat = 110

    init(viewModel: StudySessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: CodeySpacing.md) {
            topBar
            if let summary = viewModel.summary {
                StudySummaryView(
                    deck: viewModel.deck,
                    summary: summary,
                    wasEmpty: viewModel.wasEmpty,
                    studyAgain: { withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.restart() } },
                    done: { dismiss() }
                )
            } else if let card = viewModel.currentCard {
                cardArea(card)
                controls
            }
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.bottom, CodeySpacing.sm)
        .codeyPaperBackground()
        .background { keyboardShortcuts }
        .badgeBanner()
        .sensoryFeedback(trigger: feedbackEvent) { _, new in new?.rating.feedback }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: CodeySpacing.md) {
            CloseButton(label: "Close", hint: "Your progress is saved") { dismiss() }
                .accessibilityIdentifier("study.close")

            if viewModel.summary == nil {
                ProgressBar(value: viewModel.queue.progress)
                Text(counterText)
                    .font(.codeyNumericSmall)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel(counterAccessibilityLabel)
                    .accessibilityIdentifier("study.counter")
            } else {
                Spacer()
            }
        }
        .padding(.top, CodeySpacing.xs)
    }

    /// "3 / 12", "3 / 12 · +1 repeat", or "Repeat 1 of 2" (S19): cards that
    /// "Again" adds are announced as soon as they're added.
    private var counterText: String {
        let queue = viewModel.queue
        if queue.isRepeat { return "Repeat \(queue.repeatPosition) of \(queue.repeatCount)" }
        let base = "\(queue.displayPosition) / \(queue.distinctTotal)"
        guard queue.repeatCount > 0 else { return base }
        return "\(base) · +\(queue.repeatCount.counted("repeat"))"
    }

    private var counterAccessibilityLabel: String {
        let queue = viewModel.queue
        if queue.isRepeat { return "Repeat \(queue.repeatPosition) of \(queue.repeatCount)" }
        let base = "Card \(queue.displayPosition) of \(queue.distinctTotal)"
        guard queue.repeatCount > 0 else { return base }
        return "\(base), \(queue.repeatCount.counted("repeat")) added"
    }

    // MARK: Card

    private func cardArea(_ card: Flashcard) -> some View {
        let candidate = CardRating.forSwipe(drag, threshold: 24)
        let pastThreshold = CardRating.forSwipe(drag, threshold: Self.swipeThreshold)
        let dragProgress = min(max(abs(drag.width), abs(drag.height)) / Self.swipeThreshold, 1)

        return StudyCardView(
            card: card,
            isRevealed: viewModel.isRevealed,
            masteredBadge: masteredBadge,
            scoreChange: scoreChange,
            isRepeat: viewModel.queue.isRepeat
        )
            .overlay {
                if let candidate {
                    RoundedRectangle.codey(CodeyRadius.lg)
                        .strokeBorder(candidate.tint, lineWidth: 3)
                        .opacity(dragProgress)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                if let pastThreshold {
                    CodeyChip(pastThreshold.title, variant: pastThreshold.chipVariant)
                        .padding(.top, CodeySpacing.sm)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .id(card.id)
            .transition(
                .asymmetric(
                    insertion: CodeyMotion.popTransition(reduceMotion: reduceMotion),
                    removal: .opacity
                )
            )
            .offset(drag)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag.width / 20)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            // Simultaneous: Textual's link overlay puts a tap gesture on every
            // line of card text, which would otherwise win and leave only the
            // empty card space flipping it.
            .simultaneousGesture(TapGesture().onEnded { flip() })
            .gesture(swipeGesture, isEnabled: viewModel.hasRevealedCurrent && !isCommitting)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(viewModel.isRevealed ? "Double tap to show the prompt" : "Double tap to show the answer")
            .accessibilityAction { flip() }
            .accessibilityActions {
                if viewModel.hasRevealedCurrent {
                    ForEach(CardRating.allCases, id: \.self) { rating in
                        Button("Rate \(rating.title)") { commit(rating) }
                    }
                }
            }
            .accessibilityIdentifier("study.card")
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { drag = $0.translation }
            .onEnded { value in
                guard let rating = CardRating.forSwipe(value.translation, threshold: Self.swipeThreshold) else {
                    withCodeyAnimation(CodeyMotion.smooth, reduceMotion: reduceMotion) { drag = .zero }
                    return
                }
                commit(rating, fromSwipe: value.translation)
            }
    }

    // MARK: Controls

    /// Caption under the card: how to flip, then how to rate.
    private var controls: some View {
        ZStack {
            if viewModel.hasRevealedCurrent {
                SwipeHint()
                    .transition(.opacity)
            } else {
                Text("Tap the card to see the answer")
                    .font(.codeyCallout)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 44)
        .codeyAnimation(CodeyMotion.snappy, value: viewModel.hasRevealedCurrent)
        .accessibilityHidden(true) // the card's own actions cover VoiceOver
    }

    /// Hardware keyboard: Space flips (FR-16); 1–4 rate after reveal.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("Flip card") { flip() }
                .keyboardShortcut(.space, modifiers: [])
            ForEach(CardRating.allCases, id: \.self) { rating in
                Button(rating.title) { commit(rating) }
                    .keyboardShortcut(rating.keyEquivalent, modifiers: [])
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func flip() {
        guard !isCommitting, viewModel.summary == nil else { return }
        viewModel.toggleReveal()
    }

    /// Rates the card. The card settles back and its dots show the new
    /// score and the change ("+2", "Reset") for a moment (S19); a rating
    /// that masters it also shows the "Mastered" chip. A swipe then flies
    /// the card off-screen.
    private func commit(_ rating: CardRating, fromSwipe translation: CGSize? = nil) {
        guard !isCommitting, viewModel.hasRevealedCurrent, let card = viewModel.currentCard else { return }
        isCommitting = true
        feedbackEvent = FeedbackEvent(rating: rating)

        let newScore = rating.applied(to: card.masteryScore)
        let willMaster = !card.isMastered && newScore >= Flashcard.maxMastery
        Task { @MainActor in
            withCodeyAnimation(CodeyMotion.smooth, reduceMotion: reduceMotion) {
                drag = .zero
                scoreChange = .init(previous: card.masteryScore, new: newScore)
                if willMaster {
                    masteredBadge = viewModel.deck.origin == .starter ? .masteredAndRetired : .mastered
                }
            }
            try? await Task.sleep(for: .milliseconds(willMaster ? 900 : 650))
            if let translation, !reduceMotion {
                withAnimation(.easeIn(duration: 0.2)) {
                    drag = CGSize(width: translation.width * 4, height: translation.height * 4)
                }
                try? await Task.sleep(for: .milliseconds(200))
            }

            masteredBadge = nil
            scoreChange = nil
            drag = .zero
            withCodeyAnimation(CodeyMotion.snappy, reduceMotion: reduceMotion) {
                _ = viewModel.rate(rating)
            }
            isCommitting = false
        }
    }

    private struct FeedbackEvent: Equatable {
        let id = UUID()
        let rating: CardRating
    }
}

/// "← Again  ↓ Hard  ↑ Easy  Good →" in each rating's color (symbol + word,
/// never color alone).
private struct SwipeHint: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CodeySpacing.md) { items }
            Grid(horizontalSpacing: CodeySpacing.md, verticalSpacing: CodeySpacing.xs) {
                GridRow { item(.again); item(.good) }
                GridRow { item(.hard); item(.easy) }
            }
        }
        .font(.codeyCallout.weight(.semibold))
    }

    private var items: some View {
        ForEach(CardRating.swipeHintOrder, id: \.self) { item($0) }
    }

    private func item(_ rating: CardRating) -> some View {
        Label(rating.title, systemImage: rating.swipeSymbol)
            .foregroundStyle(rating.tint)
            .lineLimit(1)
    }
}
