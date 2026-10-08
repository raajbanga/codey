import SwiftData
import SwiftUI
import os

/// Profile + settings (replaces the Settings tab, 7.3). A native
/// inset-grouped List opened from the avatar on Home.
struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(BackendFacade.self) private var backend
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false

    @Query private var profiles: [UserProfile]
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query(filter: #Predicate<FlashcardDeck> { $0.isHidden && $0.deletedAt == nil }, sort: \FlashcardDeck.title)
    private var hiddenDecks: [FlashcardDeck]

    @State private var confirmReset = false
    @State private var confirmErase = false
    @State private var confirmSignOut = false
    @State private var actionError: String?

    private var profile: UserProfile? { profiles.first }
    private var xp: Int { profile?.totalXP ?? 0 }

    var body: some View {
        NavigationStack {
            List {
                header
                accountSection
                appearanceSection
                studySection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("profile.done")
                }
            }
        }
        .confirmationDialog("Reset progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) {
                perform {
                    try LocalDataReset.resetProgress(context: modelContext)
                    backend.didResetProgress()
                }
            }
        } message: {
            Text("XP, streak, card mastery, quiz progress, and tier unlocks go back to zero. Your decks stay. This can't be undone.")
        }
        .confirmationDialog("Erase all local data?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                perform {
                    try LocalDataReset.eraseAllLocalData(context: modelContext, bank: QuestionBankLoader.loadBank())
                }
            }
        } message: {
            Text("Your decks, progress, and profile will be deleted from this device. This can't be undone.")
        }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Remove Decks from This Device", role: .destructive) {
                Task { await backend.signOut(removingLocalDecks: true) }
            }
            Button("Keep Decks on This Device") {
                Task { await backend.signOut(removingLocalDecks: false) }
            }
        } message: {
            Text(signOutMessage)
        }
        .alert("Something Went Wrong", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: Sections

    private var header: some View {
        Section {
            HStack(spacing: CodeySpacing.md) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.codeyDisplay)
                    .imageScale(.large)
                    .foregroundStyle(CodeyColor.brand)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                    Text(profile?.username ?? UserProfile.defaultUsername)
                        .font(.codeyTitle)
                    Text("Level \(LevelCalculator.level(forXP: xp)) · \(xp.formatted()) XP")
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                    Text(accountStatus)
                        .font(.codeyCaption)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            }
            .padding(.vertical, CodeySpacing.xs)
            .accessibilityElement(children: .combine)
        }
    }

    private var accountStatus: String {
        guard let user = backend.currentUser else { return "Guest · data stays on this device" }
        return "Signed in as \(user.email ?? user.displayName ?? "Google user")"
    }

    @ViewBuilder
    private var accountSection: some View {
        if let user = backend.currentUser {
            Section {
                LabeledContent("Account", value: user.email ?? user.displayName ?? "Google")
                LabeledContent("Last synced") {
                    if let date = backend.lastSyncedAt {
                        Text(date, format: .relative(presentation: .named))
                    } else {
                        Text("Not yet")
                    }
                }
                LabeledContent("Pending changes", value: backend.pendingCount.formatted())
                Button {
                    Task { await backend.syncPending() }
                } label: {
                    HStack {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if backend.engine.isSyncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(backend.engine.isSyncing)
                .accessibilityIdentifier("profile.syncNow")
                Button("Sign Out", role: .destructive) { confirmSignOut = true }
                    .accessibilityIdentifier("profile.signOut")
            } header: {
                Text("Account")
            } footer: {
                if let error = backend.engine.lastError {
                    Text("Last sync failed: \(error) Codey will retry automatically.")
                } else {
                    Text("Your decks, display name, and XP sync across devices.")
                }
            }
        } else {
            Section {
                Button {
                    Task { await backend.signInWithGoogle() }
                } label: {
                    HStack {
                        Label("Sign in with Google", systemImage: "person.badge.key")
                        Spacer()
                        if backend.authState == .signingIn {
                            ProgressView()
                        }
                    }
                }
                .disabled(!backend.isSignInAvailable || backend.authState == .signingIn)
                .accessibilityIdentifier("profile.signIn")
            } header: {
                Text("Account")
            } footer: {
                if case .error(let message) = backend.authState {
                    Text(message)
                } else {
                    Text(backend.isSignInAvailable
                         ? "Sign in to back up your decks and XP and sync them across devices. Codey works fully without an account."
                         : "Cloud sync isn't set up in this build. Everything is saved on this device.")
                }
            }
        }
    }

    private var signOutMessage: String {
        let pending = backend.unsyncedChangeCount
        let warning = pending > 0
            ? "\(pending) change\(pending == 1 ? "" : "s") haven't synced yet and will be lost if you remove your decks. "
            : ""
        return warning + "Removing them keeps another account from uploading them. They're safe in your account and come back when you sign in again."
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private var studySection: some View {
        Section {
            ForEach(topics) { topic in
                let pinned = profile?.pinnedTopicIds.contains(topic.id) == true
                Button {
                    togglePin(topic.id)
                } label: {
                    HStack {
                        Label(topic.title, systemImage: topic.iconName)
                            .foregroundStyle(CodeyColor.textPrimary)
                        Spacer()
                        if pinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(CodeyColor.brand)
                        }
                    }
                }
                .accessibilityValue(pinned ? "Pinned" : "Not pinned")
                .accessibilityHint("Pinned topics show first on Home and in Decks")
            }
            if !hiddenDecks.isEmpty {
                ForEach(hiddenDecks) { deck in
                    HStack {
                        Label(deck.title, systemImage: "eye.slash")
                            .foregroundStyle(CodeyColor.textSecondary)
                        Spacer()
                        Button("Restore") {
                            perform { try backend.setHidden(false, deck: deck) }
                        }
                        .buttonStyle(.borderless)
                        .tint(CodeyColor.brand)
                    }
                }
            }
        } header: {
            Text("Study")
        } footer: {
            Text(hiddenDecks.isEmpty
                 ? "Pinned topics show first on Home and in Decks."
                 : "Pinned topics show first on Home and in Decks. Hidden starter decks are listed above.")
        }
    }

    private var dataSection: some View {
        Section {
            Button("Reset Progress", role: .destructive) { confirmReset = true }
            Button("Erase All Local Data", role: .destructive) { confirmErase = true }
                .disabled(backend.currentUser != nil)
        } header: {
            Text("Data")
        } footer: {
            Text(backend.currentUser == nil
                 ? "Reset progress keeps your decks. Erase deletes everything on this device."
                 : "Reset progress keeps your decks. To erase everything on this device, sign out first.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Self.versionString)
            NavigationLink("Acknowledgements") { AcknowledgementsView() }
            #if DEBUG
            Button("Replay Onboarding") {
                hasCompletedOnboarding = false
                dismiss()
            }
            #endif
        }
    }

    // MARK: Actions

    private func togglePin(_ topicId: String) {
        let profile = DataSeeder.ensureProfile(context: modelContext)
        if let index = profile.pinnedTopicIds.firstIndex(of: topicId) {
            profile.pinnedTopicIds.remove(at: index)
        } else {
            profile.pinnedTopicIds.append(topicId)
        }
        perform { try modelContext.save() }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            Logger.settings.error("Profile action failed: \(String(describing: error))")
            actionError = error.localizedDescription
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Open-source credits (NFR-15 as amended by D1).
private struct AcknowledgementsView: View {
    private static let libraries: [(name: String, detail: String)] = [
        ("Textual", "Markdown rendering · gonzalezreal · MIT"),
        ("swiftui-math", "Math rendering (via Textual) · gonzalezreal · MIT"),
        ("swift-concurrency-extras", "via Textual · Point-Free · MIT"),
        ("Runestone", "Code editor · Simon B. Støvring · MIT"),
        ("TreeSitterLanguages", "Syntax grammars · Simon B. Støvring · MIT"),
        ("Tree-sitter", "Parsing library · MIT"),
        ("Prism", "Syntax highlighting (bundled in Textual) · MIT"),
        ("Supabase Swift", "Auth and sync · Supabase · MIT"),
        ("swift-clocks", "via Supabase · Point-Free · MIT"),
        ("xctest-dynamic-overlay", "via Supabase · Point-Free · MIT"),
        ("swift-crypto", "via Supabase · Apple · Apache 2.0"),
        ("swift-asn1", "via Supabase · Apple · Apache 2.0"),
        ("swift-http-types", "via Supabase · Apple · Apache 2.0"),
        ("Google Sign-In", "Sign in with Google · Google · Apache 2.0"),
        ("AppAuth", "via Google Sign-In · OpenID Foundation · Apache 2.0"),
        ("GTMAppAuth", "via Google Sign-In · Google · Apache 2.0"),
        ("GTMSessionFetcher", "via Google Sign-In · Google · Apache 2.0"),
        ("GoogleUtilities", "via Google Sign-In · Google · Apache 2.0"),
        ("App Check", "via Google Sign-In · Google · Apache 2.0"),
        ("Interop for Google SDKs", "via Google Sign-In · Google · Apache 2.0"),
        ("Promises", "via Google Sign-In · Google · Apache 2.0"),
    ]

    var body: some View {
        List(Self.libraries, id: \.name) { library in
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(library.name)
                    .font(.codeyHeadline)
                Text(library.detail)
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
        }
        .navigationTitle("Acknowledgements")
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    ProfileSheet()
        .modelContainer(container)
        .environment(BackendFacade.localOnly(context: container.mainContext))
}
