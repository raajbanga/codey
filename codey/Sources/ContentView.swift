import SwiftData
import SwiftUI

public struct ContentView: View {
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false

    public init() {}

    public var body: some View {
        RootView()
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding && !AppLaunchOptions.skipsOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView { hasCompletedOnboarding = true }
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(ModelContainerFactory.makePreview())
}
