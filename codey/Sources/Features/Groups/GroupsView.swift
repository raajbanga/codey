import SwiftUI

/// FR-42, FR-50–52: your leaderboard groups. Pushed from Home. Signed-in
/// only; offline it shows the last fetched list with an "as of" time.
struct GroupsView: View {
    @Environment(BackendFacade.self) private var backend

    @State private var list = CachedList<GroupSummary>()
    @State private var sheet: GroupSheet?
    /// Your rank on each group's board (shared ranks, FR-42).
    @State private var ranks: [UUID: Int] = [:]
    /// Your XP this week: this device's count, or your row on a board if
    /// that's higher (it adds up every device).
    @State private var weeklyXP = WeeklyXPStore().xp()

    var body: some View {
        CodeyPage("Groups", subtitle: "Weekly XP Boards", icon: "trophy") {
            if backend.currentUser != nil {
                CodeyMenu(.icon("plus", label: "Add group")) {
                    CodeyMenuItem("Create Group", systemImage: "plus") { sheet = .create }
                    CodeyMenuItem("Join with Code", systemImage: "number") { sheet = .join }
                }
                .accessibilityIdentifier("groups.add")
            }
        } leading: {
            // What you've earned this week, the number the boards rank.
            HeaderBadge(value: weeklyXP, icon: "bolt", ink: CodeyColor.xp, fill: CodeyColor.xpSoft, unit: "XP")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(weeklyXP) XP this week")
        } content: {
            if backend.currentUser == nil {
                EmptyStateView(
                    systemImage: "person.2",
                    title: "Sign in for groups",
                    message: "Sign in from your profile to create or join a group."
                )
            } else {
                if let error = list.error {
                    StaleNotice(message: error, fetchedAt: list.fetchedAt)
                        .codeyCard()
                }
                if list.items.isEmpty, !list.isLoading {
                    EmptyStateView(
                        systemImage: "person.3",
                        title: "No groups yet",
                        message: "Groups rank members by XP earned this week. Create one and share its code, or join with a friend's code.",
                        actionTitle: "Create Group"
                    ) { sheet = .create }
                } else {
                    BentoSection("Your groups") {
                        ForEach(list.items) { group in
                            NavigationLink {
                                GroupBoardView(group: group)
                            } label: {
                                GameTile(
                                    icon: "person.3",
                                    title: group.name,
                                    detail: "Code \(group.inviteCode)",
                                    hue: group.hue,
                                    action: TileAction("Board", icon: "trophy")
                                ) {
                                    // Your place on this board, top right like a quest's XP.
                                    if let rank = ranks[group.id] {
                                        CodeyChip(GroupBoardView.ordinal(rank), systemImage: "medal", variant: .xp)
                                            .accessibilityLabel("You're \(GroupBoardView.ordinal(rank))")
                                    }
                                }
                            }
                            .buttonStyle(TilePressStyle())
                            .accessibilityIdentifier("groups.row")
                        }
                    }
                }
            }
        }
        .overlay {
            if list.isLoading, list.items.isEmpty { ProgressView() }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $sheet) { kind in
            NavigationStack {
                switch kind {
                case .create: CreateGroupView { add($0) }
                case .join: JoinGroupView { add($0) }
                }
            }
            .codeyOverlayHost()
            // Passed in by hand: on Mac Catalyst presented content doesn't
            // inherit Observable objects (opening Profile crashed, Nov 16).
            .environment(backend)
        }
    }

    private func load() async {
        guard backend.currentUser != nil else { return }
        await list.load(
            cached: backend.cachedGroups.map { ($0.groups, $0.fetchedAt) },
            failure: "Couldn't refresh groups.",
            fetch: backend.fetchGroups
        )
        await loadRanks()
    }

    /// Your rank and XP from the saved boards first, then fresh ones (one
    /// sync, every board fetched at once).
    private func loadRanks() async {
        let me = backend.currentUser?.id
        func apply(_ entries: [LeaderboardEntry], to group: UUID) {
            guard let row = LeaderboardRanking.rank(entries, me: me).first(where: \.isMe) else { return }
            ranks[group] = row.rank
            weeklyXP = max(weeklyXP, row.entry.xp)
        }
        for group in list.items {
            if let cached = backend.cachedLeaderboard(for: group.id) { apply(cached.entries, to: group.id) }
        }
        for (group, entries) in await backend.fetchLeaderboards(for: list.items.map(\.id)) {
            apply(entries, to: group)
        }
    }

    private func add(_ group: GroupSummary) {
        list.items.removeAll { $0.id == group.id }
        list.items.append(group)
    }
}

extension GroupSummary {
    /// A steady color per group, from its id, for its tile.
    var hue: CodeyColor.TopicHue {
        let colors = ProfileAvatar.Color.allCases
        return colors[Int(id.uuid.0) % colors.count].hue
    }
}

private enum GroupSheet: String, Identifiable {
    case create, join
    var id: String { rawValue }
}

/// "Couldn't refresh. Showing results as of 2:14 PM."
struct StaleNotice: View {
    let message: String
    let fetchedAt: Date?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(message)
                if let fetchedAt {
                    Text("Showing what was saved \(fetchedAt, format: .relative(presentation: .named)).")
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            }
        } icon: {
            Icon("wifi.exclamationmark", relativeTo: .subheadline)
                .foregroundStyle(CodeyColor.warning)
        }
    }
}

/// FR-50: name → the server makes a code → share it.
struct CreateGroupView: View {
    @Environment(BackendFacade.self) private var backend
    let onCreated: (GroupSummary) -> Void

    @State private var name = ""
    @FocusState private var focused: Bool
    @State private var created: GroupSummary?
    @State private var isSaving = false
    @State private var actionError: String?

    private var limit: Int { ModelValidator.Limits.groupName.upperBound }
    private var length: Int { ModelValidator.measuredLength(name) }
    private var isValid: Bool { ModelValidator.validateGroupName(name).isEmpty }

    var body: some View {
        CodeyPage(
            created?.name ?? "New Group",
            subtitle: created == nil ? "You'll get a code to share." : "Share this code to invite people.",
            icon: "person.3",
            closes: true,
            closeID: "groups.create.close"
        ) {
            if created == nil {
                PageAction(systemImage: "checkmark", label: "Create", isWorking: isSaving, action: create)
                    .disabled(!isValid)
                    .accessibilityIdentifier("groups.create.save")
            }
        } content: {
            if let created {
                InviteCodeCard(group: created)
                FieldNote("Anyone with this code can join and see the group's weekly board.")
            } else {
                TextField("Group name", text: $name)
                    .font(.codeyBody)
                    .submitLabel(.done)
                    .onSubmit(create)
                    .focused($focused)
                    .onAppear { focused = true }
                    .codeyField()
                    .accessibilityIdentifier("groups.create.name")
                LimitCounter(count: length, limit: limit)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, CodeySpacing.xs)
            }
        }
        .errorAlert($actionError)
    }

    private func create() {
        guard isValid, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            await $actionError.attempt("Couldn't create the group. Check your connection and try again.") {
                let group = try await backend.createGroup(name: name)
                onCreated(group)
                withAnimation(CodeyMotion.smooth) { created = group }
            }
        }
    }
}

/// FR-51: a 6-character code, case-insensitive.
struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BackendFacade.self) private var backend
    let onJoined: (GroupSummary) -> Void

    @State private var code = ""
    @FocusState private var focused: Bool
    @State private var isJoining = false
    @State private var actionError: String?

    private var isValid: Bool { ModelValidator.validateInviteCode(code).isEmpty }

    var body: some View {
        CodeyPage(
            "Join a Group",
            subtitle: "Ask a group member for its 6-character code.",
            icon: "number",
            closes: true,
            closeID: "groups.join.close"
        ) {
            PageAction(systemImage: "checkmark", label: "Join", isWorking: isJoining, action: join)
                .disabled(!isValid)
                .accessibilityIdentifier("groups.join.save")
        } content: {
            TextField("ABC234", text: $code)
                .font(.codeyNumeric)
                .kerning(4)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: code) { _, new in
                    let cleaned = String(ModelValidator.normalizedInviteCode(new).prefix(ModelValidator.Limits.inviteCodeLength))
                    if cleaned != new { code = cleaned }
                }
                .submitLabel(.join)
                .onSubmit(join)
                .focused($focused)
                .onAppear { focused = true }
                .codeyField()
                .accessibilityLabel("Invite code")
                .accessibilityIdentifier("groups.join.code")
        }
        .errorAlert($actionError)
    }

    private func join() {
        guard isValid, !isJoining else { return }
        isJoining = true
        Task {
            defer { isJoining = false }
            await $actionError.attempt("Couldn't join. Check your connection and try again.") {
                onJoined(try await backend.joinGroup(code: code))
                dismiss()
            }
        }
    }
}

/// The invite code, large, with a share button, on a note.
struct InviteCodeCard: View {
    let group: GroupSummary

    var body: some View {
        VStack(spacing: CodeySpacing.md) {
            Text(group.inviteCode)
                .font(.codeyNumeric)
                .kerning(6)
                .foregroundStyle(CodeyColor.textPrimary)
                .textSelection(.enabled)
                .accessibilityLabel("Invite code \(group.inviteCode.map(String.init).joined(separator: " "))")
            ShareLink(
                item: "Join my Codey group \"\(group.name)\" with code \(group.inviteCode).",
                subject: Text("Join my Codey group")
            ) {
                HStack(spacing: CodeySpacing.sm) {
                    Icon("square.and.arrow.up", size: 18, relativeTo: .title2)
                    Text("Share Code")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CodeyFillButtonStyle(kind: .secondary))
            .accessibilityIdentifier("groups.share")
        }
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity)
        .codeyNote()
    }
}

/// A caption under a field on a bento page.
private struct FieldNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.codeyCaption)
            .foregroundStyle(CodeyColor.textSecondary)
            .padding(.horizontal, CodeySpacing.xs)
    }
}
