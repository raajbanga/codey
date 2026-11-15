import SwiftData
import SwiftUI
import os

/// Boot screen: opens (and migrates) the SwiftData store, seeds the question
/// bank and starter decks, catches up badges, builds the BackendFacade, then
/// shows ContentView. A failed open offers retry or an explicit store reset;
/// user data is never deleted silently.
struct LoadingView: View {
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var container: ModelContainer?
    @State private var backend: BackendFacade?
    @State private var showResetConfirmation = false
    @State private var showsProgress = false

    /// The glyph and progress bar appear only if boot takes longer than
    /// this. A fast boot shows just the paper, then Home: no flash, and no
    /// minimum wait.
    private let revealDelay: Duration = .milliseconds(300)

    var body: some View {
        Group {
            if let container, let backend {
                ContentView()
                    .modelContainer(container)
                    .environment(backend)
            } else {
                loadingContent
            }
        }
        .task {
            await runBootSequence()
        }
    }

    private var loadingContent: some View {
        loadingStack
            .opacity(showsProgress || errorMessage != nil ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .codeyPaperBackground()
            .task {
                try? await Task.sleep(for: revealDelay)
                withAnimation(CodeyMotion.snappy) { showsProgress = true }
            }
    }

    private var loadingStack: some View {
        VStack(spacing: CodeySpacing.lg) {
            Spacer()
            AppGlyph(size: 88)
            Text("Codey")
                .font(.codeyDisplay)
                .foregroundStyle(CodeyColor.textPrimary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CodeySpacing.md)

                CodeyButton("Try Again", kind: .secondary) {
                    retryBoot()
                }
                .padding(.horizontal, CodeySpacing.xl)

                CodeyButton("Reset Local Data", kind: .destructive) {
                    showResetConfirmation = true
                }
                .padding(.horizontal, CodeySpacing.xl)
            } else {
                ProgressBar(value: progress)
                    .frame(maxWidth: 180)
                    .accessibilityLabel("Loading")
            }
            Spacer()
            Spacer()
        }
        .codeyConfirm(
            "Reset local data?",
            isPresented: $showResetConfirmation,
            message: "Codey couldn't open its data. Resetting deletes your decks, XP, and progress on this device."
        ) {
            [CodeyDialog.Action("Delete Local Data", isDestructive: true, action: resetStoreAndRetry)]
        }
        .codeyOverlayHost()
    }

    private func retryBoot() {
        errorMessage = nil
        progress = 0
        Task { await runBootSequence() }
    }

    private func resetStoreAndRetry() {
        do {
            try ModelContainerFactory.destroyStore()
            retryBoot()
        } catch {
            errorMessage = "Couldn't delete local data: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func runBootSequence() async {
        guard container == nil, errorMessage == nil else { return }

        do {
            let bootContainer = try ModelContainerFactory.make(inMemory: AppLaunchOptions.usesInMemoryStore)
            progress = 0.25

            let context = bootContainer.mainContext
            let stamp = BundledContentStamp.current()
            if let stamp, BundledContentStamp.isSeeded(stamp, context: context) {
                // Same bundle as last launch: nothing to upsert.
                DataSeeder.ensureProfile(context: context)
                Logger.seeding.info("Bundled content unchanged; seeding skipped")
            } else {
                let bank = try QuestionBankLoader.loadBank()
                progress = 0.50

                try DataSeeder.seed(context: context, bank: bank)
                progress = 0.75

                do {
                    try StarterDeckLoader.seed(context: context)
                    if let stamp { BundledContentStamp.record(stamp) }
                } catch {
                    // Starter decks are optional content: log, don't block boot.
                    Logger.seeding.error("Starter decks failed to load: \(String(describing: error))")
                }
            }
            do {
                // Catches up badges already qualified for (an upgrade from a
                // build without them), before any banner is watching.
                try BadgeEvaluator.award(context: bootContainer.mainContext)
                try bootContainer.mainContext.save()
            } catch {
                Logger.seeding.error("Badge catch-up failed: \(String(describing: error))")
            }
            progress = 1.0

            let facade = AppLaunchOptions.usesInMemoryStore
                ? BackendFacade.localOnly(context: bootContainer.mainContext)
                : BackendFacade.live(context: bootContainer.mainContext)
            facade.start()
            backend = facade
            container = bootContainer
        } catch {
            Logger.persistence.error("Boot failed: \(String(describing: error))")
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

#Preview {
    LoadingView()
}
