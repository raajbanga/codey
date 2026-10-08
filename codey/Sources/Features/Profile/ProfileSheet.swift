import SwiftData
import SwiftUI
import os

/// Profile + settings (replaces the Settings tab, 7.3). A native
/// inset-grouped List opened from the avatar on Home.
struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false

    @Query private var profiles: [UserProfile]
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query(filter: #Predicate<FlashcardDeck> { $0.isHidden && $0.deletedAt == nil }, sort: \FlashcardDeck.title)
    private var hiddenDecks: [FlashcardDeck]

    @State private var confirmReset = false
    @State private var confirmErase = false
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
                perform { try LocalDataReset.resetProgress(context: modelContext) }
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
                    Text("Guest · data stays on this device")
                        .font(.codeyCaption)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            }
            .padding(.vertical, CodeySpacing.xs)
            .accessibilityElement(children: .combine)
        }
    }

    private var accountSection: some View {
        Section {
            Button {
                // Stage 9: BackendFacade.signInWithGoogle()
            } label: {
                Label("Sign in with Google", systemImage: "person.badge.key")
            }
            .disabled(true)
        } header: {
            Text("Account")
        } footer: {
            Text(AppConfig.current.isBackendConfigured
                 ? "Sign-in and cloud sync are coming in a later update."
                 : "Cloud sync isn't set up in this build. Everything is saved on this device.")
        }
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
                            perform { try LocalOnlyBackend(context: modelContext).setHidden(false, deck: deck) }
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
        } header: {
            Text("Data")
        } footer: {
            Text("Reset progress keeps your decks. Erase deletes everything on this device.")
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
    ProfileSheet()
        .modelContainer(ModelContainerFactory.makePreview())
}
