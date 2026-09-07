import SwiftData
import SwiftUI

struct LoadingView: View {
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var container: ModelContainer?

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
                .font(.system(size: 48))
                .foregroundStyle(ThemeColor.primary)

            Text("Codey")
                .font(.codeyHeadline)

            if let errorMessage {
                Text(errorMessage)
                    .font(.codeySubheadline)
                    .foregroundStyle(ThemeColor.destructive)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CodeySpacing.md)
            } else {
                CodeyProgress(value: progress, label: "Loading…")
                    .padding(.horizontal, CodeySpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColor.canvas)
    }

    @MainActor
    private func runBootSequence() async {
        guard container == nil, errorMessage == nil else { return }

        do {
            let bootContainer = try ModelContainerFactory.make()
            progress = 0.25

            let context = bootContainer.mainContext
            let shouldSeed = DataSeeder.needsSeeding(context: context)
            progress = 0.50
            if !shouldSeed { try await Task.sleep(for: stepDelay) }

            let topics = try QuestionBankLoader.loadTopics()
            progress = 0.75
            if !shouldSeed { try await Task.sleep(for: stepDelay) }

            if shouldSeed {
                try DataSeeder.seed(context: context, topics: topics)
            }
            progress = 1.0
            if !shouldSeed { try await Task.sleep(for: stepDelay) }

            container = bootContainer
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

#Preview {
    LoadingView()
}
