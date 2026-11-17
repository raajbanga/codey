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
struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: StudySessionViewModel

    @State private var isCommitting = false
    @State private var masteredBadge: StudyCardView.MasteredBadge?
    @State private var scoreChange: StudyCardView.ScoreChange?
    @State private var feedbackEvent: FeedbackEvent?
    @State private var toast: XPToast?

    init(viewModel: StudySessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let summary = viewModel.summary {
                // No top bar: Done closes (Nov 15).
                StudySummaryView(
                    deck: viewModel.deck,
                    summary: summary,
                    wasEmpty: viewModel.wasEmpty,
                    studyAgain: { withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.restart() } },
                    done: { dismiss() }
                )
                .padding(.horizontal, CodeySpacing.md)
            } else if let card = viewModel.currentCard {
                VStack(spacing: CodeySpacing.md) {
                    cardArea(card)
                    controls
                }
                .padding([.horizontal, .bottom], CodeySpacing.md)
                .codeyReadableWidth()
                // The bar and its fade span the screen; its controls line up with
                // the card's readable column on iPad.
                .codeyBar(.top) { topBar.padding(.horizontal, CodeySpacing.md).codeyReadableWidth() }
            }
        }
        .codeyPaperBackground()
        .background { keyboardShortcuts }
        .xpToast($toast)
        .badgeBanner()
        .sensoryFeedback(trigger: feedbackEvent) { _, new in new?.rating.feedback }
    }

    // MARK: Top bar

    private var topBar: some View {
        SessionTopBar(
            closeLabel: "Close",
            closeHint: "Your progress is saved",
            closeID: "study.close",
            close: { dismiss() }
        ) {
            // Ticks only (§3b, Nov 15): "6 / 6 · +2 repeats" beside them
            // crowded the bar. Repeats are extra ticks and a Repeat tag on
            // the card; VoiceOver still hears the count.
            SessionProgress(
                done: doneColors,
                total: viewModel.queue.total,
                accessibilityLabel: counterAccessibilityLabel,
                accessibilityValue: viewModel.queue.progress.formatted(.percent.precision(.fractionLength(0)))
            )
            .accessibilityIdentifier("study.counter")
        } trailing: {
            // XP so far, as in a quiz (S41): +5 a card moved up.
            SessionXP(amount: viewModel.xpEarned)
                .accessibilityIdentifier("study.xp")
        }
    }

    /// A tick per card in the queue (repeats add one): rated ones in their
    /// rating's color; cards rated before a resume in brand.
    private var doneColors: [Color] {
        let rated = viewModel.queue.position
        let known = viewModel.ratings.suffix(rated).map(\.tint)
        return Array(repeating: CodeyColor.brand, count: rated - known.count) + known
    }

    /// "Card 3 of 12", "…, 1 repeat added", or "Repeat 1 of 2" (S19): cards
    /// that "Again" adds are announced as soon as they're added.
    private var counterAccessibilityLabel: String {
        let queue = viewModel.queue
        if queue.isRepeat { return "Repeat \(queue.repeatPosition) of \(queue.repeatCount)" }
        let base = "Card \(queue.displayPosition) of \(queue.distinctTotal)"
        guard queue.repeatCount > 0 else { return base }
        return "\(base), \(queue.repeatCount.counted("repeat")) added"
    }

    // MARK: Card

    private func cardArea(_ card: Flashcard) -> some View {
        // Each card owns its drag (SwipeCard), so a drag frame only moves
        // the card (Nov 15: swiping lagged). Cards never overlap: the old
        // one goes at once (a swiped one is already off screen) and the new
        // one pops in on its own (Nov 15: the old card flashed its answer).
        SwipeCard(isEnabled: viewModel.hasRevealedCurrent && !isCommitting, flies: !reduceMotion) { rating in
            commit(rating, swiped: true)
        } card: {
            StudyCardView(
                card: card,
                isRevealed: viewModel.isRevealed,
                masteredBadge: masteredBadge,
                scoreChange: scoreChange,
                isRepeat: viewModel.queue.isRepeat
            )
        }
            // A fresh view per review, so a repeat of the card just rated
            // comes in on its prompt instead of flipping back in place.
            .id(CardTurn(card: card.id, review: viewModel.reviewedCount))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            // Simultaneous: Textual's link overlay puts a tap gesture on every
            // line of card text, which would otherwise win and leave only the
            // empty card space flipping it.
            .simultaneousGesture(TapGesture().onEnded { flip() })
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

    /// Rates the card. The haptic plays at once.
    ///
    /// A swipe flies the card off the way it went (SwipeCard); the next card
    /// pops in and the toast says what changed. A key or VoiceOver rating
    /// has no motion to keep, so the card stays and its dots show the new
    /// score and the change for a moment (S19), with "Mastered" if it masters.
    private func commit(_ rating: CardRating, swiped: Bool = false) {
        guard !isCommitting, viewModel.hasRevealedCurrent, let card = viewModel.currentCard else { return }
        isCommitting = true
        feedbackEvent = FeedbackEvent(rating: rating)

        let newScore = rating.applied(to: card.masteryScore)
        let willMaster = !card.isMastered && newScore >= Flashcard.maxMastery
        let flewOff = swiped && !reduceMotion
        Task { @MainActor in
            if flewOff {
                // SwipeCard is flying the card off; wait for it to leave.
                try? await Task.sleep(for: SwipeMotion.flyOffDuration)
            } else {
                withCodeyAnimation(CodeyMotion.smooth, reduceMotion: reduceMotion) {
                    scoreChange = .init(previous: card.masteryScore, new: newScore)
                    if willMaster {
                        masteredBadge = viewModel.deck.origin == .starter ? .masteredAndRetired : .mastered
                    }
                }
                try? await Task.sleep(for: .milliseconds(willMaster ? 900 : 650))
            }

            // No animation: the old card goes at once (see cardArea).
            let outcome = withTransaction(\.disablesAnimations, true) {
                masteredBadge = nil
                scoreChange = nil
                return viewModel.rate(rating)
            }
            if let next = Self.toast(for: outcome, mastered: willMaster && flewOff) {
                withCodeyAnimation(CodeyMotion.pop, reduceMotion: reduceMotion) { toast = next }
            }
            isCommitting = false
        }
    }

    /// A bonus outranks mastering, which outranks the card's own +5. A
    /// card rated in place already showed its "Mastered" chip.
    private static func toast(for outcome: StudySessionViewModel.RatingOutcome?, mastered: Bool) -> XPToast? {
        guard let outcome else { return nil }
        if let bonus = outcome.bonuses.last { return .bonus(bonus) }
        if mastered { return .mastered(xp: outcome.xp) }
        return outcome.xp > 0 ? .xp(outcome.xp) : nil
    }

    private struct CardTurn: Hashable {
        let card: UUID
        let review: Int
    }

    private struct FeedbackEvent: Equatable {
        let id = UUID()
        let rating: CardRating
    }
}

/// The card under the finger: the rating outline and tag as it nears a
/// rating, moved and tilted with the drag (`SwipeMotion`). Past the
/// threshold it flies off the way it was thrown and reports the rating.
private struct SwipeCard<Card: View>: View {
    let isEnabled: Bool
    /// Off under Reduce Motion: the card stays and springs back.
    let flies: Bool
    let rate: (CardRating) -> Void
    @ViewBuilder var card: Card

    @State private var drag = CGSize.zero
    @State private var appeared = false

    var body: some View {
        let candidate = CardRating.forSwipe(drag, threshold: 24)
        let pastThreshold = CardRating.forSwipe(drag, threshold: SwipeMotion.threshold)
        let progress = min(max(abs(drag.width), abs(drag.height)) / SwipeMotion.threshold, 1)
        card
            // Drawn by the card's own note (NoteSurface), so it hugs the card
            // whatever its size, not this view's frame (on iPad and Mac the
            // card is narrower than the space it is centred in).
            .environment(\.noteOutline, candidate.map { NoteOutline(color: $0.tint.opacity(progress)) })
            .overlay(alignment: .top) {
                if let pastThreshold {
                    CodeyChip(pastThreshold.title, variant: pastThreshold.chipVariant)
                        .padding(.top, CodeySpacing.sm)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .swipeFollow(drag, tilts: flies)
            // Pops in itself (CodeyMotion.pop), so no transition has the old
            // and new card on screen together.
            .scaleEffect(appeared || !flies ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
            .onAppear { withAnimation(flies ? CodeyMotion.pop : nil) { appeared = true } }
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { drag = $0.translation }
                    .onEnded { value in
                        let rating = CardRating.forSwipe(value.translation, threshold: SwipeMotion.threshold)
                        if let rating { rate(rating) }
                        if rating != nil, flies {
                            Task { await SwipeMotion.flyOff(along: value.translation) { drag = $0 } }
                        } else {
                            withAnimation(CodeyMotion.smooth) { drag = .zero }
                        }
                    },
                isEnabled: isEnabled
            )
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
