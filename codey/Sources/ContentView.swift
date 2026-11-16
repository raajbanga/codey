import SwiftData
import SwiftUI

/// Root after boot: the tab UI (RootView) with onboarding as a full-screen
/// cover until it's finished, and a sync nudge whenever the app becomes active.
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
                    .scrollIndicators(.hidden)
            }
            .onOpenURL { backend.handle($0) }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: backend.appDidBecomeActive()
                case .background: backend.appDidEnterBackground()
                default: break
                }
            }
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    ContentView()
        .modelContainer(container)
        .environment(BackendFacade.localOnly(context: container.mainContext))
}
