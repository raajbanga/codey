import SwiftData
import SwiftUI
import os

struct LoadingView: View {
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var container: ModelContainer?
    @State private var showResetConfirmation = false

    private let stepDelay: Duration = .milliseconds(200)

    var body: some View {
        Group {
            if let container {
                ContentView()
                    .modelContainer(container)
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
            Image(systemName: "terminal.fill")
                .font(.codeyDisplay)
                .imageScale(.large)
                .foregroundStyle(CodeyColor.brand)

            Text("Codey")
                .font(.codeyHeadline)

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
                ProgressBar(value: progress, label: "Loading…")
                    .padding(.horizontal, CodeySpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CodeyColor.surface)
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

        do {
            let bootContainer = try ModelContainerFactory.make(inMemory: AppLaunchOptions.usesInMemoryStore)
            progress = 0.25

            let bank = try QuestionBankLoader.loadBank()
            progress = 0.50
            try await Task.sleep(for: stepDelay)

            try DataSeeder.seed(context: bootContainer.mainContext, bank: bank)
            progress = 1.0
            try await Task.sleep(for: stepDelay)

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
