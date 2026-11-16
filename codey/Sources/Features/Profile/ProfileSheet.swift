import SwiftData
import SwiftUI

/// Profile + settings (replaces the Settings tab, 7.3), opened from the
/// avatar on Play. Bento layout (S42): a hero card in the avatar's color,
/// then one note per group of settings.
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
            CodeyPage("Profile", closes: true, closeID: "profile.done") {
                NavigationLink {
                    ProfileEditorView()
                } label: {
                    CircleIcon(systemImage: "pencil", kind: .soft)
                }
                .buttonStyle(TilePressStyle())
                .accessibilityLabel("Edit profile")
                .accessibilityIdentifier("profile.edit")
            } hero: {
                hero
            } content: {
                NoteGroup("Badges") { BadgesRow() }
                accountSection
                appearanceSection
                studySection
                dataSection
                aboutSection
            }
        }
        .codeyConfirm(
            "Reset progress?",
            isPresented: $confirmReset,
            message: "XP, streak, badges, card mastery, quiz progress, and tier unlocks go back to zero. Your decks stay. This can't be undone."
        ) {
            [CodeyDialog.Action("Reset Progress", isDestructive: true) {
                $actionError.attempt {
                    try LocalDataReset.resetProgress(context: modelContext)
                    backend.didResetProgress()
                }
            }]
        }
        .codeyConfirm(
            "Erase all local data?",
            isPresented: $confirmErase,
            message: "Your decks, progress, and profile will be deleted from this device. This can't be undone."
        ) {
            [CodeyDialog.Action("Erase Everything", isDestructive: true) {
                $actionError.attempt {
                    let content = try ContentSeeder.load().content
                    try LocalDataReset.eraseAllLocalData(context: modelContext, bank: content.bank, decks: content.decks)
                }
            }]
        }
        .codeyConfirm("Sign out?", isPresented: $confirmSignOut, message: signOutMessage) {
            [
                CodeyDialog.Action("Remove Decks from This Device", isDestructive: true) {
                    Task { await backend.signOut(removingLocalDecks: true) }
                },
                CodeyDialog.Action("Keep Decks on This Device") {
                    Task { await backend.signOut(removingLocalDecks: false) }
                },
            ]
        }
        .errorAlert($actionError)
        .codeyOverlayHost()
    }

    // MARK: Sections

    private var hue: CodeyColor.TopicHue { ProfileAvatar.color(for: profile?.avatarId).hue }

    /// Name, account, level and XP; the pencil above edits the name and
    /// avatar (FR-04).
    private var hero: some View {
        let level = LevelCalculator.level(forXP: xp)
        return HeroCard(
            title: profile?.username ?? UserProfile.defaultUsername,
            subtitle: accountStatus,
            icon: ProfileAvatar.glyph(for: ProfileAvatar.symbol(for: profile?.avatarId)),
            hue: hue,
            progress: LevelCalculator.progressFraction(xp)
        ) {
            CodeyChip("Level \(level)", systemImage: "star.fill", variant: .xp)
        }
    }

    private var accountStatus: String {
        backend.currentUser == nil ? "Guest. Your data stays on this device." : "Signed in with Google"
    }

    @ViewBuilder
    private var accountSection: some View {
        if backend.currentUser != nil {
            NoteGroup("Account", footer: backend.engine.lastError.map { "Last sync failed: \($0) Codey will retry automatically." }
                          ?? "Your decks, progress, streak, badges, and XP sync across devices.") {
                SettingsRow(icon: "arrow.triangle.2.circlepath", title: "Last synced") {
                    if let date = backend.lastSyncedAt {
                        Text(date, format: .relative(presentation: .named))
                    } else {
                        Text("Not yet")
                    }
                }
                SettingsRow(icon: "icloud.and.arrow.up", title: "Pending changes") {
                    Text(backend.pendingCount.formatted())
                }
                HStack(spacing: CodeySpacing.sm) {
                    CodeyButton(backend.engine.isSyncing ? "Syncing" : "Sync Now", systemImage: "arrow.triangle.2.circlepath",
                                kind: .secondary, fullWidth: true, compact: true) {
                        Task { await backend.syncPending() }
                    }
                    .disabled(backend.engine.isSyncing)
                    .accessibilityIdentifier("profile.syncNow")
                    CodeyButton("Sign Out", kind: .destructive, fullWidth: true, compact: true) { confirmSignOut = true }
                        .accessibilityIdentifier("profile.signOut")
                }
                .padding(.top, CodeySpacing.xs)
            }
        } else {
            NoteGroup("Account", footer: signInFooter) {
                CodeyButton(backend.authState == .signingIn ? "Signing In" : "Sign in with Google",
                            systemImage: "person.crop.circle", fullWidth: true) {
                    Task { await backend.signInWithGoogle() }
                }
                .disabled(!backend.isSignInAvailable || backend.authState == .signingIn)
                .accessibilityIdentifier("profile.signIn")
            }
        }
    }

    private var signInFooter: String {
        if case .error(let message) = backend.authState { return message }
        return backend.isSignInAvailable
            ? "Sign in to back up your decks and XP and sync them across devices. Codey works fully without an account."
            : "Cloud sync isn't set up in this build. Everything is saved on this device."
    }

    private var signOutMessage: String {
        let pending = backend.unsyncedChangeCount
        let warning = pending > 0
            ? "\(pending.counted("change")) haven't synced yet and will be lost if you remove your decks. "
            : ""
        return warning + "Removing them keeps another account from uploading them. They're safe in your account and come back when you sign in again."
    }

    private var appearanceSection: some View {
        NoteGroup("Appearance") {
            ChoiceChips("Appearance", selection: $appearance, options: AppAppearance.allCases.map { ($0, $0.title) }, fills: true)
        }
    }

    private var studySection: some View {
        NoteGroup("Pinned topics", footer: "Pinned topics show first on Play and in Decks." + (hiddenDecks.isEmpty ? "" : " Hidden starter decks are listed below them.")) {
            ForEach(topics) { topic in
                let pinned = profile?.pinnedTopicIds.contains(topic.id) == true
                let topicHue = CodeyColor.TopicHue.of(topicID: topic.id)
                Button {
                    togglePin(topic.id)
                } label: {
                    SettingsRow(icon: topic.iconName, title: topic.title, hue: topicHue) {
                        Icon(pinned ? "pin.fill" : "pin", size: 18, relativeTo: .headline)
                            .foregroundStyle(pinned ? topicHue.fill : CodeyColor.textSecondary)
                    }
                }
                .buttonStyle(TilePressStyle())
                .accessibilityValue(pinned ? "Pinned" : "Not pinned")
                .accessibilityHint("Pinned topics show first on Play and in Decks")
            }
            ForEach(hiddenDecks) { deck in
                SettingsRow(icon: "eye.slash", title: deck.title) {
                    CodeyButton("Restore", kind: .secondary, compact: true) {
                        $actionError.attempt { try backend.setHidden(false, deck: deck) }
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        NoteGroup("Data", footer: backend.currentUser == nil
                      ? "Reset progress keeps your decks. Erase deletes everything on this device."
                      : "Reset progress keeps your decks. To erase everything on this device, sign out first.") {
            HStack(spacing: CodeySpacing.sm) {
                CodeyButton("Reset Progress", kind: .destructive, fullWidth: true, compact: true) { confirmReset = true }
                CodeyButton("Erase All Data", kind: .destructive, fullWidth: true, compact: true) { confirmErase = true }
                    .disabled(backend.currentUser != nil)
                    .accessibilityLabel("Erase All Local Data")
            }
        }
    }

    private var aboutSection: some View {
        NoteGroup("About") {
            SettingsRow(icon: "number", title: "Version") { Text(Self.versionString) }
            NavigationLink {
                FeedbackFormView()
            } label: {
                SettingsRow(icon: "questionmark.bubble", title: "Report a UI/UX Issue") { RowChevron() }
            }
            .buttonStyle(TilePressStyle())
            .accessibilityIdentifier("profile.feedback")
            NavigationLink {
                AcknowledgementsView()
            } label: {
                SettingsRow(icon: "heart", title: "Acknowledgements") { RowChevron() }
            }
            .buttonStyle(TilePressStyle())
            #if DEBUG
            Button {
                hasCompletedOnboarding = false
                dismiss()
            } label: {
                SettingsRow(icon: "arrow.counterclockwise", title: "Replay Onboarding") { RowChevron() }
            }
            .buttonStyle(TilePressStyle())
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
        $actionError.attempt { try modelContext.save() }
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
        CodeyPage("Acknowledgements", subtitle: "Open-source code in Codey", icon: "heart") {
                ForEach(Self.libraries, id: \.name) { library in
                    VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                        Text(library.name)
                            .font(.codeyHeadline)
                            .foregroundStyle(CodeyColor.textPrimary)
                        Text(library.detail)
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                    .codeyCard()
                    .accessibilityElement(children: .combine)
                }
        }
    }
}

/// One settings line: an icon tile, a title, and a trailing value or control.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    /// Nil: the app accent (the avatar's color).
    var hue: CodeyColor.TopicHue?
    @ViewBuilder var trailing: Trailing

    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 34
    @Environment(\.appHue) private var appHue

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            IconTile(systemName: icon, size: tile, radius: CodeyRadius.sm, ink: (hue ?? appHue ?? .slate).ink, tile: (hue ?? appHue ?? .slate).soft)
            Text(title)
                .font(.codeyBody)
                .foregroundStyle(CodeyColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: CodeySpacing.xs)
            trailing
                .font(.codeySubheadline)
                .foregroundStyle(CodeyColor.textSecondary)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    ProfileSheet()
        .modelContainer(container)
        .environment(BackendFacade.localOnly(context: container.mainContext))
}
