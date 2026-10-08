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
///     ✕        ━━━━━━━━━──────  3 / 12
///     ╭ card (tap / Space to flip) ╮
///     (Again) (Hard) (Good) (Easy)     ← after reveal; swipes ← → ↑
struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: StudySessionViewModel

    @State private var drag: CGSize = .zero
    @State private var isCommitting = false
    @State private var masteredBadge: StudyCardView.MasteredBadge?
    @State private var feedbackEvent: FeedbackEvent?

    private static let swipeThreshold: CGFloat = 110

    init(request: StudyRequest, context: ModelContext) {
        _viewModel = State(initialValue: StudySessionViewModel(deck: request.deck, start: request.start, context: context))
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
        .background(CodeyColor.surface.ignoresSafeArea())
        .background { flipShortcut }
        .sensoryFeedback(trigger: feedbackEvent) { _, new in new?.rating.feedback }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: CodeySpacing.md) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.codeyHeadline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")
            .accessibilityHint("Your progress is saved")
            .accessibilityIdentifier("study.close")

            if viewModel.summary == nil {
                ProgressBar(value: viewModel.queue.progress)
                Text("\(viewModel.queue.displayPosition) / \(viewModel.queue.total)")
                    .font(.codeyNumericSmall)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Card \(viewModel.queue.displayPosition) of \(viewModel.queue.total)")
            } else {
                Spacer()
            }
        }
        .padding(.top, CodeySpacing.xs)
    }

    // MARK: Card

    private func cardArea(_ card: Flashcard) -> some View {
        let candidate = CardRating.forSwipe(drag, threshold: 24)
        let pastThreshold = CardRating.forSwipe(drag, threshold: Self.swipeThreshold)
        let dragProgress = min(max(abs(drag.width), abs(drag.height)) / Self.swipeThreshold, 1)

        return StudyCardView(card: card, isRevealed: viewModel.isRevealed, masteredBadge: masteredBadge)
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
                    CodeyChip(pastThreshold.title, variant: chipVariant(pastThreshold))
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
            .onTapGesture { flip() }
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
                    withCodeyAnimation(CodeyMotion.bouncy, reduceMotion: reduceMotion) { drag = .zero }
                    return
                }
                commit(rating, fromSwipe: value.translation)
            }
    }

    // MARK: Controls

    private var controls: some View {
        ZStack {
            if viewModel.hasRevealedCurrent {
                RatingBar(isEnabled: !isCommitting) { commit($0) }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    flip()
                } label: {
                    Text("Show Answer")
                        .font(.codeyHeadline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(CodeyColor.brandFill)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .accessibilityIdentifier("study.reveal")
                .transition(.opacity)
            }
        }
        .frame(minHeight: 64)
        .codeyAnimation(CodeyMotion.snappy, value: viewModel.hasRevealedCurrent)
    }

    /// Space on a hardware keyboard flips the card (FR-16).
    private var flipShortcut: some View {
        Button("Flip card") { flip() }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Actions

    private func flip() {
        guard !isCommitting, viewModel.summary == nil else { return }
        viewModel.toggleReveal()
    }

    /// Rates the card. A rating that masters the card first shows the
    /// "Mastered" chip on it; a swipe first flies the card off-screen.
    private func commit(_ rating: CardRating, fromSwipe translation: CGSize? = nil) {
        guard !isCommitting, viewModel.hasRevealedCurrent, let card = viewModel.currentCard else { return }
        isCommitting = true
        feedbackEvent = FeedbackEvent(rating: rating)

        let willMaster = !card.isMastered && rating.applied(to: card.masteryScore) >= Flashcard.maxMastery
        Task { @MainActor in
            if willMaster {
                withCodeyAnimation(CodeyMotion.bouncy, reduceMotion: reduceMotion) {
                    drag = .zero
                    masteredBadge = viewModel.deck.origin == .starter ? .masteredAndRetired : .mastered
                }
                try? await Task.sleep(for: .milliseconds(900))
            } else if let translation, !reduceMotion {
                withAnimation(.easeIn(duration: 0.2)) {
                    drag = CGSize(width: translation.width * 4, height: translation.height * 4)
                }
                try? await Task.sleep(for: .milliseconds(200))
            }

            masteredBadge = nil
            drag = .zero
            withCodeyAnimation(CodeyMotion.snappy, reduceMotion: reduceMotion) {
                _ = viewModel.rate(rating)
            }
            isCommitting = false
        }
    }

    private func chipVariant(_ rating: CardRating) -> CodeyChipVariant {
        switch rating {
        case .again: .danger
        case .hard: .warning
        case .good: .brand
        case .easy: .success
        }
    }

    private struct FeedbackEvent: Equatable {
        let id = UUID()
        let rating: CardRating
    }
}

/// The four glass rating buttons with their mastery-delta hints (FR-17, D14).
private struct RatingBar: View {
    let isEnabled: Bool
    let rate: (CardRating) -> Void

    var body: some View {
        GlassEffectContainer(spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.sm) {
                ForEach(CardRating.allCases, id: \.self) { rating in
                    Button {
                        rate(rating)
                    } label: {
                        VStack(spacing: CodeySpacing.xxs) {
                            Text(rating.title)
                                .font(.codeyHeadline)
                            Text(rating.deltaHint)
                                .font(.codeyCaption.monospacedDigit())
                        }
                        .foregroundStyle(rating.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: CodeyRadius.md))
                    .keyboardShortcut(rating.keyEquivalent, modifiers: [])
                    .accessibilityLabel(rating.title)
                    .accessibilityHint(rating.accessibilityHint)
                    .accessibilityIdentifier("study.rate.\(rating.rawValue)")
                }
            }
        }
        .disabled(!isEnabled)
    }
}
