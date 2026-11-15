import SwiftUI

/// FR-42, FR-50–52: your leaderboard groups. Pushed from Home. Signed-in
/// only; offline it shows the last fetched list with an "as of" time.
struct GroupsView: View {
    @Environment(BackendFacade.self) private var backend

    @State private var list = CachedList<GroupSummary>()
    @State private var sheet: GroupSheet?

    var body: some View {
        List {
            if backend.currentUser == nil {
                Section {
                    Label("Sign in from your profile to create or join a group.", systemImage: "person.2.slash")
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            } else {
                if let error = list.error {
                    Section {
                        StaleNotice(message: error, fetchedAt: list.fetchedAt)
                    }
                }
                if list.items.isEmpty, !list.isLoading {
                    Section {
                        Text("Groups rank members by XP earned this week. Create one and share its code, or join with a friend's code.")
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                } else {
                    Section {
                        ForEach(list.items) { group in
                            NavigationLink {
                                GroupBoardView(group: group)
                            } label: {
                                Label(group.name, systemImage: "person.3.fill")
                                    .font(.codeyBody)
                            }
                            .accessibilityIdentifier("groups.row")
                        }
                    } footer: {
                        Text("Weeks reset Monday 00:00 UTC.")
                    }
                }
            }
        }
        .codeyListBackground()
        .codeyPageTitle("Groups")
        .toolbar {
            if backend.currentUser != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Create Group", systemImage: "plus") { sheet = .create }
                        Button("Join with Code", systemImage: "number") { sheet = .join }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add group")
                    .accessibilityIdentifier("groups.add")
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
        }
    }

    private func load() async {
        guard backend.currentUser != nil else { return }
        await list.load(
            cached: backend.cachedGroups.map { ($0.groups, $0.fetchedAt) },
            failure: "Couldn't refresh groups.",
            fetch: backend.fetchGroups
        )
    }

    private func add(_ group: GroupSummary) {
        list.items.removeAll { $0.id == group.id }
        list.items.append(group)
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
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(CodeyColor.warning)
        }
    }
}

/// FR-50: name → the server makes a code → share it.
struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BackendFacade.self) private var backend
    let onCreated: (GroupSummary) -> Void

    @State private var name = ""
    @State private var created: GroupSummary?
    @State private var isSaving = false
    @State private var actionError: String?

    private var limit: Int { ModelValidator.Limits.groupName.upperBound }
    private var length: Int { ModelValidator.measuredLength(name) }
    private var isValid: Bool { ModelValidator.validateGroupName(name).isEmpty }

    var body: some View {
        Form {
            if let created {
                Section {
                    InviteCodeCard(group: created)
                } footer: {
                    Text("Anyone with this code can join and see the group's weekly board.")
                }
            } else {
                Section {
                    TextField("Group name", text: $name)
                        .submitLabel(.done)
                        .onSubmit(create)
                        .accessibilityIdentifier("groups.create.name")
                } footer: {
                    HStack {
                        Text("You'll get a code to share.")
                        Spacer()
                        Text("\(length)/\(limit)")
                            .monospacedDigit()
                            .foregroundStyle(length > limit ? CodeyColor.danger : CodeyColor.textSecondary)
                    }
                    .font(.codeyCaption)
                }
            }
        }
        .codeyListBackground()
        .codeyPageTitle(created == nil ? "New Group" : created!.name)
        .toolbar {
            if created == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Create", action: create)
                            .disabled(!isValid)
                            .accessibilityIdentifier("groups.create.save")
                    }
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
    @State private var isJoining = false
    @State private var actionError: String?

    private var isValid: Bool { ModelValidator.validateInviteCode(code).isEmpty }

    var body: some View {
        Form {
            Section {
                TextField("ABC234", text: $code)
                    .font(.codeyNumeric)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: code) { _, new in
                        let cleaned = String(ModelValidator.normalizedInviteCode(new).prefix(ModelValidator.Limits.inviteCodeLength))
                        if cleaned != new { code = cleaned }
                    }
                    .submitLabel(.join)
                    .onSubmit(join)
                    .accessibilityLabel("Invite code")
                    .accessibilityIdentifier("groups.join.code")
            } footer: {
                Text("Ask a group member for its 6-character code.")
            }
        }
        .codeyListBackground()
        .codeyPageTitle("Join a Group")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isJoining {
                    ProgressView()
                } else {
                    Button("Join", action: join)
                        .disabled(!isValid)
                        .accessibilityIdentifier("groups.join.save")
                }
            }
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

/// The invite code, large, with a share button.
struct InviteCodeCard: View {
    let group: GroupSummary

    var body: some View {
        VStack(spacing: CodeySpacing.sm) {
            Text(group.inviteCode)
                .font(.codeyNumeric)
                .kerning(4)
                .textSelection(.enabled)
                .accessibilityLabel("Invite code \(group.inviteCode.map(String.init).joined(separator: " "))")
            ShareLink(
                item: "Join my Codey group \"\(group.name)\" with code \(group.inviteCode).",
                subject: Text("Join my Codey group")
            ) {
                Label("Share Code", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("groups.share")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CodeySpacing.sm)
    }
}
