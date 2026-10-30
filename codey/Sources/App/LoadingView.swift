import SwiftData
import SwiftUI
import os

struct LoadingView: View {
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var container: ModelContainer?
    @State private var backend: BackendFacade?
    @State private var showResetConfirmation = false

    /// Keeps the launch screen up at least this long so it doesn't flash.
    private let minimumDuration: Duration = .milliseconds(400)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .codeyPaperBackground()
        .confirmationDialog(
            "Reset local data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Local Data", role: .destructive) {
                resetStoreAndRetry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Codey couldn't open its data. Resetting deletes your decks, XP, and progress on this device.")
        }
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

        let started = ContinuousClock.now
        do {
            let bootContainer = try ModelContainerFactory.make(inMemory: AppLaunchOptions.usesInMemoryStore)
            progress = 0.25

            let bank = try QuestionBankLoader.loadBank()
            progress = 0.50

            try DataSeeder.seed(context: bootContainer.mainContext, bank: bank)
            progress = 0.75

            do {
                try StarterDeckLoader.seed(context: bootContainer.mainContext)
            } catch {
                // Starter decks are optional content: log, don't block boot.
                Logger.seeding.error("Starter decks failed to load: \(String(describing: error))")
            }
            progress = 1.0
            let elapsed = ContinuousClock.now - started
            if elapsed < minimumDuration {
                try await Task.sleep(for: minimumDuration - elapsed)
            }

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
