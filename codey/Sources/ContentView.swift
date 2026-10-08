import SwiftData
import SwiftUI

public struct ContentView: View {
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false
    @Environment(BackendFacade.self) private var backend
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        RootView()
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding && !AppLaunchOptions.skipsOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView { hasCompletedOnboarding = true }
            }
            .onOpenURL { backend.handle($0) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { backend.appDidBecomeActive() }
            }
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    ContentView()
        .modelContainer(container)
        .environment(BackendFacade.localOnly(context: container.mainContext))
}
